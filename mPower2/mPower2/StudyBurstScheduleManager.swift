//
//  StudyBurstScheduleManager.swift
//  mPower2
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import BridgeApp
import UserNotifications


/// The study burst configuration is a Decodable that can be added to the `AppConfig.clientData`.
public struct StudyBurstConfiguration : Codable {
    
    private enum CodingKeys : String, CodingKey {
        case identifier, numberOfDays, minimumRequiredDays, expiresLimit, taskGroupIdentifier, motivationIdentifier, completionTasks, engagementDataGroups
    }
    
    /// The task identifier.
    public let identifier: String

    /// The number of days in the study burst.
    public let numberOfDays: Int
    
    public let minimumRequiredDays: Int
    
    /// The time limit until the progress expires.
    public let expiresLimit: TimeInterval
    
    /// The task group used to mark the active tasks included in the study burst.
    public let taskGroupIdentifier: RSDIdentifier
    
    /// The identifier for the initial engagement survey.
    public let motivationIdentifier: RSDIdentifier
    
    /// The completion tasks for each day of the study burst.
    let completionTasks: [CompletionTask]
    
    /// List of the possible engagement data groups.
    let engagementDataGroups: [[String]]?
    
    public init() {
        self.identifier = RSDIdentifier.studyBurstCompletedTask.stringValue
        self.numberOfDays = 14
        self.minimumRequiredDays = 10
        self.expiresLimit = 60 * 60
        self.taskGroupIdentifier = .measuringTaskGroup
        self.completionTasks = [
            CompletionTask(day: 1, activityIdentifiers:[.studyBurstReminder, .demographics]),
            CompletionTask(day: 9, activityIdentifiers:[.background]),
            CompletionTask(day: 14, activityIdentifiers: [.engagement])
        ]
        self.engagementDataGroups = [
            ["gr_SC_DB","gr_SC_CS"],
            ["gr_BR_AD","gr_BR_II"],
            ["gr_ST_T","gr_ST_F"],
            ["gr_DT_F","gr_DT_T"]]
        self.motivationIdentifier = .motivation
    }
    
    struct CompletionTask : Codable {
        let day: Int
        let activityIdentifiers: [RSDIdentifier]
        
        func preferredIdentifier() -> RSDIdentifier? {
            return Set(activityIdentifiers).intersection([.demographics, .engagement]).first ?? activityIdentifiers.first
        }
    }

    public var completionTaskIdentifiers: [RSDIdentifier] {
        var taskIds = completionTasks.flatMap { $0.activityIdentifiers }
        taskIds.append(self.motivationIdentifier)
        return taskIds
    }
    
    /// Returns a randomized list of possible combinations of engagement groups.
    func randomEngagementGroups() -> Set<String>? {
        guard let groups = self.engagementDataGroups else { return nil }
        return Set(groups.compactMap { $0.randomElement() })
    }
}

let kCompletionTaskIdentifier: String = "TempStudyBurstCompletionTask"

struct TodayActionBarItem {
    let title: String
    let detail: String?
    let icon: UIImage?
}


/// The study burst manager is accessible on the "Today" view as well as being used to manage the study burst
/// view controller.
class StudyBurstScheduleManager : TaskGroupScheduleManager {
    
    static var shared = StudyBurstScheduleManager()
    
    // Bridge doesn't support the concept of a skipped task that we can store, so
    // instead we'll track it locally
    open var skippedTasks: [RSDTaskInfo] = []
    
    /// The configuration is set up either by the bridge configuration or using defaults defined internally.
    lazy var studyBurst: StudyBurstConfiguration! = {
        return (SBABridgeConfiguration.shared as? MP2BridgeConfiguration)?.studyBurst ?? StudyBurstConfiguration()
    }()
    
    /// Return the activity group set by the navigator.
    override public var activityGroup: SBAActivityGroup? {
        get {
            let studyBurst = self.studyBurst ?? StudyBurstConfiguration()
            let groupId = studyBurst.taskGroupIdentifier.stringValue
            let activityGroup = configuration.activityGroup(with: groupId)
            return activityGroup ?? SBAActivityGroupObject(identifier: groupId,
                                                           title: Localization.localizedString(groupId),
                                                           journeyTitle: nil,
                                                           image: nil,
                                                           activityIdentifiers: RSDIdentifier.measuringTasks,
                                                           notificationIdentifier: nil,
                                                           schedulePlanGuid: nil,
                                                           activityGuidMap: nil)
        }
        set {
            // Do nothing
            assertionFailure("Set is overridden to be ignored.")
        }
    }
    
    /// The number of days in the study burst.
    public var numberOfDays: Int {
        return studyBurst.numberOfDays
    }
    
    /// The time limit until the progress expires.
    public var expiresLimit: TimeInterval {
        return studyBurst.expiresLimit
    }
    
    /// Is there an active study burst?
    public var hasStudyBurst : Bool {
        return dayCount != nil
    }
    
    /// The maximum number of days in a study burst.
    public private(set) var maxDaysCount : Int = 19
    
    /// The count of past days in a study burst.
    public private(set) var pastDaysCount : Int = 0
    
    /// What day of the study burst should be displayed?
    public var dayCount : Int? {
        if let loadedDate = _dayCountLoaded, Calendar.iso8601.isDate(now(), inSameDayAs: loadedDate) {
            return _dayCount
        }
        else {
            // The day count has not been loaded for today so infer it.
            // Note: this will get muddled if crossing timezones, but not really sure how to work
            // around that. syoung 09/20/2019
            let dayCount = Calendar.iso8601.dateComponents([.day], from: self.studyBurstDayOne, to: now()).day! + 1
            return dayCount <= numberOfDays ? dayCount : nil
        }
    }
    private var _dayCount : Int?
    private var _dayCountLoaded : Date?
    
    /// Number of days in the study burst that were missed.
    public private(set) var missedDaysCount: Int = 0
    
    /// When does the study burst expire?
    public var expiresOn : Date? {
        // Look to see that the first task has been started and that the study burst is not completed.
        guard !isCompletedForToday, let timestamp = orderedTasks.first?.finishedOn
            else {
                return nil
        }
        return timestamp.addingTimeInterval(expiresLimit)
    }
    
    /// Has the study burst expired?
    public var hasExpired : Bool {
        guard let expiresOn = self.expiresOn else { return false }
        return today() > expiresOn
    }
    
    /// Were the tasks finished within the time limit?
    public var finishedWithinLimit : Bool {
        guard let startedOn = self.orderedTasks.first?.startedOn,
            let finishedOn = self.orderedTasks.last?.finishedOn
            else {
                return false
        }
        let dt = finishedOn.timeIntervalSinceReferenceDate - startedOn.timeIntervalSinceReferenceDate
        return dt < expiresLimit
    }
    
    /// What is the current progress on required activities?
    public var progress : CGFloat {
        return CGFloat(finishedCount) / CGFloat(totalActivitiesCount)
    }
    
    /// Is the study burst completed for today?
    public var isCompletedForToday : Bool {
        return !hasStudyBurst || (finishedCount == totalActivitiesCount)
    }
    
    /// How many of the tasks are finished?
    var finishedCount : Int {
        return self.orderedTasks.reduce(0, { $0 + ($1.finishedOn != nil ? 1 : 0) })
    }
    
    /// Has the user been shown the motivation survey?
    public var hasCompletedMotivationSurvey : Bool {
        // If the motivation survey does not include any responses then there will be no report,
        // so can only validate whether or not the schedule has been completed by looking a the
        // schedules. However, because this is checked during the startup sequence, the schedules
        // may not yet be fetched, so check both this survey *and* the cache.
        let taskPredicate = SBBScheduledActivity.activityIdentifierPredicate(with: self.studyBurst.motivationIdentifier.stringValue)
        let schedule: SBBScheduledActivity? = {
            if let schedule = self.scheduledActivities.first(where: { taskPredicate.evaluate(with: $0) }) {
                return schedule
            }
            else {
                do {
                    let schedules = try self.activityManager.getCachedSchedules(using: taskPredicate,
                                                                sortDescriptors: [],
                                                                fetchLimit: 1)
                    return schedules.first
                }
                catch {
                    return nil
                }
            }
        }()
        return schedule?.isCompleted ?? false
    }
    
    /// Is this the final study burst task for today?
    public func isFinalTask(_ taskIdentifier: String) -> Bool {
        return taskIdentifier == self.orderedTasks.last?.identifier
    }
    
    /// Total number of activities
    public var totalActivitiesCount : Int {
        return (activityGroup?.activityIdentifiers.count ?? 1)
    }
    
    /// Subset of the past survey schedules that were not finished on the day they were scheduled.
    public var pastSurveys: [RSDIdentifier] {
        let thisDay = calculateThisDay()
        return getPastSurveys(for: thisDay)
    }
    
    /// The completion task to use for today.
    public var todayCompletionTask: StudyBurstConfiguration.CompletionTask? {
        let thisDay = calculateThisDay()
        return getTodayCompletionTask(for: thisDay)
    }
    
    /// The action bar item to display.
    public var actionBarItem: TodayActionBarItem? {
        guard let (title, subtitle) = self.getUnfinishedSchedule() else { return nil }
        return TodayActionBarItem(title: title, detail: subtitle, icon: nil)
    }
    
    /// Is there something to do **today** for this study burst? This should return `true` if and only if
    /// this is a "Study Burst" day (`hasStudyBurst == true`) or there is a past schedule that is unfinished.
    public var hasActiveStudyBurst : Bool {
        return self.hasStudyBurst || self.pastSurveys.count > 0
    }
    
    public var shouldShowActionBar : Bool {
        return !self.isCompletedForToday || (self.getUnfinishedSchedule() != nil)
    }
    
    /// Should the tasks be refreshed?
    override var shouldRefreshTasks: Bool {
        let now = today()
        if let timestamp = _shuffleTimestamp, Calendar.current.isDate(timestamp, inSameDayAs: now) {
            return false
        }
        else {
            return true
        }
    }
    
    /// Returns an ordered set of task info objects. This will change each day, but should retain the saved
    /// order for any given day.
    override var taskSortOrder: [String] {
        // Look in-memory first.
        let now = today()
        if let sortTasks = _sortOrder,
            let timestamp = _shuffleTimestamp, Calendar.current.isDate(timestamp, inSameDayAs: now) {
            return sortTasks
        }

        if let storedOrder = UserDefaults.standard.array(forKey: StudyBurstScheduleManager.orderKey) as? [String],
            let timestamp = UserDefaults.standard.object(forKey: StudyBurstScheduleManager.timestampKey) as? Date,
            Calendar.current.isDate(timestamp, inSameDayAs: now) {
            _shuffleTimestamp = timestamp
            _sortOrder = storedOrder
            return storedOrder
        }
        else {
            // Otherwise, shuffle the tasks and store order of the the task identifiers.
            _sortOrder = super.taskSortOrder.shuffled()
            _shuffleTimestamp = today()
            StudyBurstScheduleManager.setOrderedTasks(_sortOrder!, timestamp: _shuffleTimestamp!)
            return _sortOrder!
        }
    }
    private var _sortOrder: [String]?
    private var _shuffleTimestamp: Date?
    
    static let orderKey = "StudyBurstTaskOrder"
    static let timestampKey = "StudyBurstTimestamp"
    static let day1StudyBurstKey = "StudyBurstDay1"
    
    var studyBurstDayOne: Date {
        get {
            return
                UserDefaults.standard.object(forKey: StudyBurstScheduleManager.day1StudyBurstKey) as? Date ?? now()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StudyBurstScheduleManager.day1StudyBurstKey)
        }
    }
    
    internal static func flushDefaults() {
        UserDefaults.standard.set(nil, forKey: orderKey)
        UserDefaults.standard.set(nil, forKey: timestampKey)
        UserDefaults.standard.set(nil, forKey: day1StudyBurstKey)
    }
    
    internal static func setOrderedTasks(_ sortOrder: [String], timestamp: Date) {
        UserDefaults.standard.set(sortOrder, forKey: orderKey)
        UserDefaults.standard.set(timestamp, forKey: timestampKey)
    }
    
    /// Is this the last day of the study burst?
    public var isLastDay: Bool {
        guard let dayCount = dayCount, hasStudyBurst else { return false }
        let days = (pastDaysCount - missedDaysCount) + 1
        return
            (days >= maxDaysCount) ||
            ((dayCount >= numberOfDays) && (days >= studyBurst.minimumRequiredDays)) ||
            ((dayCount >= numberOfDays) && !shouldContinueStudyBurst)
    }
    
    /// Should the user be shown more days of the study burst beyond the initial 14 days?
    public var shouldContinueStudyBurst : Bool {
        // TODO: syoung 06/28/2018 Implement logic to manage saving state and asking the user if they want
        // to see more days of the study rather than just assuming that they should be shown more days.
        return true
    }
    
    public func isEngagement(_ taskViewModel: RSDTaskViewModel) -> Bool {
        return taskViewModel.identifier == self.studyBurst.motivationIdentifier ||
            taskViewModel.identifier == kCompletionTaskIdentifier
    }
    
    public func engagementTaskViewModel() -> RSDTaskViewModel? {
        
        // Exit early if the motivation task hasn't been shown.
        if let taskViewModel = self.motivationTaskViewModel() {
            return taskViewModel
        }
        
        // Only return something if this is during the study burst or there is a task that chases you.
        guard self.todayCompletionTask != nil || self.pastSurveys.count > 0
            else {
                return nil
        }
        
        func step(schedule: Any) -> RSDStep? {
            if let activityReference = (schedule as? SBBScheduledActivity)?.activity.activityReference {
                if let step = activityReference as? RSDStep {
                    return step
                }
                else {
                    return RSDTaskInfoStepObject(with: activityReference)
                }
            }
            else if let identifier = (schedule as? RSDIdentifier)?.identifier ?? (schedule as? String) {
                return RSDTaskInfoStepObject(with: RSDTaskInfoObject(with: identifier))
            }
            else {
                return nil
            }
        }
        
        // Add the steps for past tasks that weren't completed and today's tasks.
        var steps: [RSDStep] = pastSurveys.compactMap {
            return step(schedule: $0)
        }
        
        // Add the tasks from today's schedule.
        let todaySchedules = getTodayCompletionSchedules()
        todaySchedules.forEach {
            if let step = step(schedule: $0) {
                steps.append(step)
            }
        }

        // If there aren't any steps then return nil.
        guard steps.count > 0 else { return nil }
        
        // Finally, create a task to run the returned steps.
        var navigator = RSDConditionalStepNavigatorObject(with: steps)
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: kCompletionTaskIdentifier, stepNavigator: navigator)
        
        // Hide cancel if this is for the initial surveys displayed before the first study burst.
        if self.dayCount == 1, self.finishedCount == 0 {
            task.shouldHideActions = [.navigation(.cancel)]
        }
        
        let path = self.instantiateTaskViewModel(for: task)
        return path.taskViewModel
    }
    
    func motivationTaskViewModel() -> RSDTaskViewModel? {
        guard !self.hasCompletedMotivationSurvey,
            let survey = self.configuration.survey(for: self.studyBurst.motivationIdentifier.moduleIdentifier.stringValue)
            else {
                return nil
        }
        return self.instantiateTaskViewModel(for: survey).taskViewModel
    }
    
    func getTodayCompletionSchedules() -> [Any] {
        guard let todayTask = self.todayCompletionTask, self.isCompletedForToday else { return [] }
        return todayTask.activityIdentifiers.compactMap { (activityIdentifier) in
            let taskPredicate = SBBScheduledActivity.activityIdentifierPredicate(with: activityIdentifier.stringValue)
            let schedulePredicate = SBBScheduledActivity.notFinishedAvailableNowPredicate()
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [taskPredicate, schedulePredicate])
            if let schedule = self.scheduledActivities.first(where: { predicate.evaluate(with: $0) }) {
                return schedule
            }
            else if !self.reports.contains(where: { $0.identifier == activityIdentifier}) {
                return activityIdentifier
            }
            else {
                return nil
            }
        }
    }
    
    /// Override to get past 14 days of study burst markers and today's activities.
    override func fetchRequests() -> [SBAScheduleManager.FetchRequest] {
        guard let group = self.activityGroup else {
            return super.fetchRequests()
        }

        let startOfToday = today().startOfDay()
        
        // Build a predicate with today's tasks
        var predicates: [NSPredicate] = group.activityIdentifiers.map {
            let predicate = SBBScheduledActivity.activityIdentifierPredicate(with:$0.stringValue)
            let start = startOfToday
            let end = start.addingNumberOfDays(1)
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                SBBScheduledActivity.availablePredicate(from: start, to: end),
                predicate])
        }
        
        // Add the completion task identifiers and the study burst reminder
        var taskIdentifiers = Set(self.studyBurst.completionTaskIdentifiers)
        taskIdentifiers.insert(.studyBurstReminder)
        taskIdentifiers.forEach {
            predicates.append(SBBScheduledActivity.activityIdentifierPredicate(with: $0.stringValue))
        }
        
        // Add the study burst marker
        let predicate = SBBScheduledActivity.activityIdentifierPredicate(with: self.studyBurst.identifier)
        let start = startOfToday.addingNumberOfDays(-2 * self.numberOfDays)
        let end = startOfToday.addingNumberOfDays(2 * self.numberOfDays)
        let studyMarkerPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SBBScheduledActivity.availablePredicate(from: start, to: end),
            predicate])
        predicates.append(studyMarkerPredicate)
        
        let filter = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return [FetchRequest(predicate: filter,
                             sortDescriptors: [SBBScheduledActivity.scheduledOnSortDescriptor(ascending: true)],
                             fetchLimit: nil)]
    }
    
    /// Override to build the new set of today history items.
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        if let studyMarker = self.getStudyBurst() {
            refreshOrderedTasks()
            // If a study marker was found, then look to see if the study burst is complete and mark it.
            if !studyMarker.isCompleted, self.totalActivitiesCount == self.finishedCount {
                self.markCompleted(studyMarker: studyMarker)
            }
        }
        else {
            self._dayCount = nil
            self._dayCountLoaded = now()
        }

        self.updateNotifications()
        
        super.didUpdateScheduledActivities(from: previousActivities)
    }
    
    /// Override isCompleted to only return true if the schedule is within the expiration window.
    override func isCompleted(for taskInfo: RSDTaskInfo, on date: Date) -> Bool {
        guard Calendar.current.isDate(date, inSameDayAs: today()),
            let scheduledTask = self.orderedTasks.first(where: { $0.identifier == taskInfo.identifier })
            else {
            return super.isCompleted(for: taskInfo, on: date)
        }
        let finishedOn = scheduledTask.finishedOn ?? Date(timeIntervalSince1970: 0)
        return Calendar.current.isDate(finishedOn, inSameDayAs: today())
    }
    
    /// Swallow the message for updated schedules if this is the study burst that we just marked as completed.
    override func willSendUpdatedSchedules(for schedules: [SBBScheduledActivity]) {
        guard schedules.count > 1 || schedules.first?.activityIdentifier != self.studyBurst.identifier
            else {
                return
        }
        super.willSendUpdatedSchedules(for: schedules)
    }
    
    private var _lastStudyBurstFinished: Date?
    
    func markCompleted(studyMarker: SBBScheduledActivity) {
        let taskOrder = self.orderedTasks
        guard let startedOn = taskOrder.first?.startedOn,
            let finishedOn = taskOrder.last?.finishedOn
            else {
                return
        }
        
        // Use an in-memory flag to ensure that this is not getting uploaded more than once per day.
        guard _lastStudyBurstFinished == nil ||
            !Calendar.current.isDate(_lastStudyBurstFinished!, inSameDayAs: today())
            else {
                return
        }
        _lastStudyBurstFinished = finishedOn
        studyMarker.startedOn = startedOn
        studyMarker.finishedOn = finishedOn
        
        let identifier = studyMarker.activityIdentifier ?? RSDIdentifier.studyBurstCompletedTask.stringValue
        let schemaInfo: RSDSchemaInfo = {
            guard let info = self.schemaInfo(for: identifier) else {
                assertionFailure("Failed to retrieve schema info for \(String(describing: studyMarker.activityIdentifier))")
                return RSDSchemaInfoObject(identifier: identifier, revision: 1)
            }
            return info
        }()
        
        do {
        
            // build the archive
            let archive = SBAScheduledActivityArchive(identifier: identifier, schemaInfo: schemaInfo, schedule: studyMarker)
            var json: [String : Any] = [ "taskOrder" : taskOrder.map({ $0.identifier}).joined(separator: ",")]
            self.orderedTasks.forEach {
                let identifier = $0.identifier
                guard let finishedOn = $0.finishedOn else { return }
                json["\(identifier).startDate"] = ($0.startedOn ?? today()).jsonObject()
                json["\(identifier).endDate"] = finishedOn.jsonObject()
                json["\(identifier).scheduleGuid"] = $0.scheduleGuid
            }
            archive.insertDictionary(intoArchive: json, filename: "tasks", createdOn: finishedOn)
            
            try archive.completeArchive(createdOn: finishedOn, with: nil)
            studyMarker.clientData = json as NSDictionary
            
            self.offMainQueue.async {
                archive.encryptAndUploadArchive()
            }
        }
        catch let err {
            debugPrint("Failed to archive the study burst data. \(err)")
        }
        
        self.sendUpdated(for: [studyMarker])
    }
    
    /// Returns the study burst completed marker for today.
    func getStudyBurst() -> SBBScheduledActivity? {
        
        let todayStart = today().startOfDay()
        let studyBurstMarkerId = self.studyBurst.identifier
        guard let studyMarker = self.scheduledActivities.first(where: {
            $0.activityIdentifier == studyBurstMarkerId && Calendar.current.isDate($0.scheduledOn, inSameDayAs: todayStart)
        })
            else {
                return nil
        }

        let markerSchedules = self.scheduledActivities.filter { studyMarker.activityIdentifier == $0.activityIdentifier }
        
        let pastSchedules = markerSchedules.filter { $0.scheduledOn < todayStart }
        let dayCount = pastSchedules.count + 1
        let missedDaysCount = pastSchedules.reduce(0, { $0 + ($1.finishedOn == nil ? 1 : 0) })
        let finishedCount = dayCount - missedDaysCount
        let hasStudyBurst = (dayCount <= self.numberOfDays) ||
            ((finishedCount < studyBurst.minimumRequiredDays) && shouldContinueStudyBurst)
        self.maxDaysCount = markerSchedules.count
        self.pastDaysCount = pastSchedules.count
        
        if hasStudyBurst {
            self._dayCount = dayCount
            self._dayCountLoaded = now()
            self.missedDaysCount = missedDaysCount
            if dayCount == 1 {
                self.studyBurstDayOne = now()
            }
        }
        else {
            self._dayCount = nil
            self._dayCountLoaded = now()
            self.missedDaysCount = 0
        }
        
        return studyMarker
    }

    func calculateThisDay() -> Int {
        guard hasStudyBurst, let day = self.dayCount else { return self.maxDaysCount + 1 }
        if day < self.studyBurst.numberOfDays {
            return day
        }
        else {
            return self.isLastDay ? self.numberOfDays : ((self.pastDaysCount - self.missedDaysCount) + 1)
        }
    }
    
    func getPastTasks(for thisDay: Int) -> [StudyBurstConfiguration.CompletionTask] {
        return self.studyBurst.completionTasks.filter {
            return $0.day < thisDay
        }
    }
    
    func getPastSurveys(for thisDay: Int) -> [RSDIdentifier] {
        let pastTasks = self.getPastTasks(for: thisDay)
        return pastTasks.flatMap { (task) -> [RSDIdentifier] in
            // Look to see if there is a report and include if *not* finished.
            let identifiers: [RSDIdentifier] = task.activityIdentifiers.filter { (identifier) in
                if self.reports.count > 0 {
                    return !self.reports.contains(where: { $0.identifier == identifier})
                }
                else {
                    do {
                        let report = try self.participantManager.getLatestCachedData(forReport: identifier.stringValue)
                        return report.data == nil || report.date == nil
                    } catch let err {
                        print("WARNING! Unexpected error while fetching latest report for \(identifier): \(err)")
                        return true
                    }
                }
            }
            let sortedIdentifiers = identifiers.sorted(by: { (lhs, rhs) in
                let lIdx = task.activityIdentifiers.firstIndex(where: { lhs == $0 }) ?? Int.max
                let rIdx = task.activityIdentifiers.firstIndex(where: { rhs == $0 }) ?? Int.max
                return lIdx < rIdx
            })
            return sortedIdentifiers
        }
    }
    
    func getTodayCompletionTask(for thisDay: Int) -> StudyBurstConfiguration.CompletionTask? {
        return self.studyBurst.completionTasks.first(where: { $0.day == thisDay})
    }
    
    func getUnfinishedSchedule() -> (title: String, subtitle: String?)? {
        // Only return the "unfinished" schedule if there is a past schedule that is following the user or
        // else the user has completed their study burst activities for today.
        guard self.pastSurveys.count > 0 || self.isCompletedForToday,
            let taskIdentifier = self.pastSurveys.first ?? self.todayCompletionTask?.preferredIdentifier(),
            !self.reports.contains(where: { $0.identifier == taskIdentifier })
            else {
                return nil
        }

        if let schedule = self.scheduledActivities.first(where: {$0.activityIdentifier == taskIdentifier.stringValue }) {
            return (schedule.activity.label, schedule.activity.labelDetail)
        }
        else {
            let activityInfo = self.configuration.activityInfo(for: taskIdentifier.stringValue)
            return (activityInfo?.title ?? taskIdentifier.stringValue, activityInfo?.subtitle)
        }
    }
    
    override open func reportQueries() -> [ReportQuery] {
        let queries = self.studyBurst.completionTaskIdentifiers.map {
            ReportQuery(reportKey: $0, queryType: .mostRecent, dateRange: nil)
        }
        return queries
    }
    
    // MARK: Study burst notification handling
    
    struct NotificationResult : Codable {
        public enum CodingKeys: String, CodingKey {
            case reminderTime, noReminder
        }
        
        let reminderTime: Date?
        let noReminder: Bool?
    }
    
    let notificationCategory = "StudyBurst"

    func updateNotifications() {
        guard let reminderTime = self.getReminderTime()
            else {
                removeAllPendingNotifications()
                return
        }
        
        // use dispatch async to allow the method to return and put updating reminders on the next run loop
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                    break   // Do nothing. We don't want to pester the user with message.
                case .notDetermined:
                    // The user has not given authorization, but the app has a record of previously requested
                    // authorization. This means that the app has been re-installed. Unfortunately, there isn't
                    // a great UI/UX for this senario, so just show the authorization request. syoung 07/19/2018
                    UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (granted, _) in
                        if granted {
                            self.updateNotifications(at: reminderTime)
                        }
                    }
                default:
                    self.updateNotifications(at: reminderTime)
                }
            }
        }
    }

    func getNotificationResult() -> NotificationResult? {
        guard let report = self.report(with: RSDIdentifier.studyBurstReminder.stringValue)
            else {
                return nil
        }
        let clientData = report.clientData
        
        do {
            if clientData is NSDictionary {
                return try SBAFactory.shared.createJSONDecoder().decode(NotificationResult.self, from: clientData)
            }
            else if let dateString = clientData as? String,
                let date = SBAFactory.shared.decodeDate(from: dateString) {
                return NotificationResult(reminderTime: date, noReminder: nil)
            }
            else {
                return NotificationResult(reminderTime: nil, noReminder: nil)
            }
        } catch let err {
            assertionFailure("Failed to decode the reminder result. \(err)")
            return nil
        }
    }
    
    func getReminderTime() -> DateComponents? {
        guard let notificationResult = getNotificationResult(),
            !(notificationResult.noReminder ?? false),
            let reminderTime = notificationResult.reminderTime
            else {
                return nil
        }
        return Calendar(identifier: .iso8601).dateComponents([.hour, .minute], from: reminderTime)
    }
    
    func getLocalNotifications(after reminderTime: DateComponents, with pendingRequests: [UNNotificationRequest]) -> (add: [UNNotificationRequest], removeIds: [String]) {
        
        let studyBurstMarkerId = self.studyBurst.identifier

        // Get future schedules.
        let date = self.today()
        let startOfToday = date.startOfDay()
        let timeToday = startOfToday.addingDateComponents(reminderTime)
        let scheduleStart = (date < timeToday) ? startOfToday : startOfToday.addingNumberOfDays(1)
        
        // Get the schedules for which to set the reminder
        var futureSchedules = self.scheduledActivities.filter {
            $0.activityIdentifier == studyBurstMarkerId &&
            $0.scheduledOn >= scheduleStart &&
            !$0.isCompleted
        }.sorted(by: { $0.scheduledOn < $1.scheduledOn })
        
        // Check if should be scheduling extra days.
        let extraDays = self.maxDaysCount - self.studyBurst.numberOfDays
        let completedCount = self.pastDaysCount - self.missedDaysCount
        if completedCount >= self.studyBurst.minimumRequiredDays {
            let toCount = futureSchedules.count - extraDays
            futureSchedules = Array(futureSchedules[..<toCount])
        }
        
        // If getting near the end, then add next cycle.
        if futureSchedules.count <= self.studyBurst.numberOfDays {
            let taskPredicate = SBBScheduledActivity.activityIdentifierPredicate(with: self.studyBurst.identifier)
            let start = startOfToday.addingNumberOfDays(self.maxDaysCount)
            let end = start.addingNumberOfYears(1)
            let studyMarkerPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SBBScheduledActivity.availablePredicate(from: start, to: end),
                taskPredicate])
            do {
                let nextSchedules = try self.activityManager.getCachedSchedules(using: studyMarkerPredicate,
                                                                            sortDescriptors: [SBBScheduledActivity.scheduledOnSortDescriptor(ascending: true)],
                                                                            fetchLimit: UInt(self.studyBurst.numberOfDays))
                futureSchedules.append(contentsOf: nextSchedules)
            }
            catch let err {
                assertionFailure("Failed to get cached schedules. \(err)")
            }
        }
        
        var pendingRequestIds = pendingRequests.map { $0.identifier }
        let requests: [UNNotificationRequest] = futureSchedules.compactMap {
            let identifier = getLocalNotificationIdentifier(for: $0, at: reminderTime)
            if pendingRequestIds.remove(where: { $0 == identifier }).count > 0 {
                // If there is an unchanged pending request, then remove it from this list
                // and do not create a new reminder for it.
                return nil
            }
            else {
                return createLocalNotification(for: $0, at: reminderTime)
            }
        }

        return (requests, pendingRequestIds)
    }
    
    func willPresentNotification(_ notification: UNNotification) {
        let nextDate = notification.date.addingNumberOfDays(90)
        guard nextDate < SBAParticipantManager.shared.startStudy.addingNumberOfYears(2)
            else { return }
        let dateComponents = Calendar.iso8601.dateComponents([.year, .month, .day, .hour, .minute],
                                                             from: nextDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let nextRequest = UNNotificationRequest(identifier: notification.request.identifier,
                                                content: notification.request.content,
                                                trigger: trigger)
        UNUserNotificationCenter.current().add(nextRequest)
    }
    
    func getLocalNotificationIdentifier(for schedule: SBBScheduledActivity, at time: DateComponents) -> String {
        let timeIdentifier = time.jsonObject()
        return "\(schedule.guid) \(timeIdentifier)"
    }
    
    func createLocalNotification(for schedule: SBBScheduledActivity, at time: DateComponents) -> UNNotificationRequest {
        guard Thread.current.isMainThread else {
            var request: UNNotificationRequest!
            DispatchQueue.main.sync {
                request = self.createLocalNotification(for: schedule, at: time)
            }
            return request
        }
        
        // Set up the notification
        let content = UNMutableNotificationContent()
        // TODO: syoung 07/19/2018 Figure out what the wording of the notification should be.
        content.body = NSLocalizedString("Time to do your mPower Study Burst activities!", comment: "Notification message")
        content.sound = UNNotificationSound.default
        content.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber;
        content.categoryIdentifier = self.notificationCategory
        content.threadIdentifier = schedule.activity.guid
        
        // Set up the trigger. Cannot schedule using a repeating notification b/c it doesn't repeat
        // every day but only every three months.
        let date = schedule.scheduledOn.startOfDay()
        var dateComponents = Calendar(identifier: .iso8601).dateComponents([.day, .month, .year], from: date)
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create the request.
        let identifier = getLocalNotificationIdentifier(for: schedule, at: time)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
    
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
            let requestIds: [String] = requests.compactMap {
                guard $0.content.categoryIdentifier == self.notificationCategory else { return nil }
                return $0.identifier
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: requestIds)
        }
    }
    
    func updateNotifications(at reminderTime: DateComponents) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { (pendingRequests) in
            let filteredRequests = pendingRequests.filter { $0.content.categoryIdentifier == self.notificationCategory }
            let notifications = self.getLocalNotifications(after: reminderTime, with: filteredRequests)
            if notifications.removeIds.count > 0 {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notifications.removeIds)
            }
            notifications.add.forEach {
                UNUserNotificationCenter.current().add($0)
            }
        }
    }
    
    public func shouldUsePreviousAnswers(for taskIdentifier: String) -> Bool {
        // Any redisplay of a question should use the previous answer if available.
        return true
    }
    
    // MARK: Study burst messaging
    
    func messageContent() -> (title: String, message: String) {
        let titleKey: String
        let messageKey: String
        if missedDaysCount <= 2, let day = dayCount {
            titleKey = "STUDY_BURST_TITLE_DAY_\(day)"
            messageKey = "STUDY_BURST_MESSAGE_DAY_\(day)"
        }
        else if missedDaysCount == 3 {
            titleKey = "STUDY_BURST_TITLE_MISSED_3"
            messageKey = "STUDY_BURST_MESSAGE_MISSED_3_RANDOM_\(Int.random(in: 0..<3))"
        }
        else if missedDaysCount <= 10 {
            titleKey = "STUDY_BURST_TITLE_MISSED_4-10_RANDOM_\(Int.random(in: 0..<6))"
            messageKey = "STUDY_BURST_TITLE_MISSED_4-10_RANDOM_\(Int.random(in: 0..<9))"
        }
        else {
            titleKey = "STUDY_BURST_TITLE_MISSED>10"
            messageKey = "STUDY_BURST_MESSAGE_MISSED>10"
        }
        return (Localization.localizedString(titleKey),
                Localization.localizedString(messageKey))
    }
}
