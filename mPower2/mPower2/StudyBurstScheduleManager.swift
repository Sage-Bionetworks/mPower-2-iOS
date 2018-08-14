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
        
        func unfinishedPredicate() -> NSPredicate {
            let unfinishedPredicate = SBBScheduledActivity.notFinishedAvailableNowPredicate()
            let activitiesPredicate = SBBScheduledActivity.includeTasksPredicate(with: activityIdentifiers.map { $0.stringValue })
            return NSCompoundPredicate(andPredicateWithSubpredicates: [unfinishedPredicate, activitiesPredicate])
        }
    }

    public var completionTaskIdentifiers: [RSDIdentifier] {
        var taskIds = completionTasks.flatMap { $0.activityIdentifiers }
        taskIds.append(self.motivationIdentifier)
        return taskIds
    }
    
    func scheduleIdentifier(for completionTask: CompletionTask) -> RSDIdentifier? {
        let identifiers = Set(completionTask.activityIdentifiers)
        if let preferred = identifiers.intersection([.demographics, .engagement]).first {
            return preferred
        }
        else {
            return identifiers.first
        }
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
    
    static let shared = StudyBurstScheduleManager()
    
    /// The configuration is set up either by the bridge configuration or using defaults defined internally.
    lazy var studyBurst: StudyBurstConfiguration! = {
        return (SBABridgeConfiguration.shared as? MP2BridgeConfiguration)?.studyBurst ?? StudyBurstConfiguration()
    }()
    
    /// Return the activity group set by the navigator.
    override public var activityGroup: SBAActivityGroup? {
        get {
            guard let groupId = studyBurst?.taskGroupIdentifier.stringValue else { return nil }
            return configuration.activityGroup(with: groupId)
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
    public private(set) var hasStudyBurst : Bool = false
    
    /// The maximum number of days in a study burst.
    public private(set) var maxDaysCount : Int = 19
    
    /// The count of past days in a study burst.
    public private(set) var pastDaysCount : Int = 0
    
    /// What day of the study burst should be displayed?
    public private(set) var dayCount : Int?
    
    /// Number of days in the study burst that were missed.
    public private(set) var missedDaysCount: Int = 0
    
    /// When does the study burst expire?
    public var expiresOn : Date? {
        guard let expiresOn = _expiresOn else { return nil }
        if expiresOn > today() {
            return expiresOn
        }
        else {
            DispatchQueue.main.async {
                self.didUpdateScheduledActivities(from: self.scheduledActivities)
            }
            return nil
        }
    }
    private var _expiresOn : Date?
    
    /// What is the current progress on required activities?
    public var progress : CGFloat {
        return CGFloat(finishedSchedules.count) / CGFloat(totalActivitiesCount)
    }
    
    /// Expose internally for testing.
    func today() -> Date {
        return Date()
    }
    
    /// Is the Study burst completed for today?
    public var isCompletedForToday : Bool {
        return !hasStudyBurst || (finishedSchedules.count == totalActivitiesCount)
    }
    
    /// Has the user been shown the motivation survey?
    public internal(set) var hasCompletedMotivationSurvey : Bool {
        get {
            guard !UserDefaults.standard.bool(forKey: "hasCompletedMotivationSurvey")
                else {
                    return true
            }
            let result = self.scheduledActivities.contains {
                $0.activityIdentifier == self.studyBurst.motivationIdentifier.stringValue && $0.isCompleted
            }
            self.hasCompletedMotivationSurvey = result
            return result
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedMotivationSurvey")
        }
    }
    
    /// Is this the final study burst task for today?
    public func isFinalTask(_ taskPath: RSDTaskPath) -> Bool {
        guard let group = self.activityGroup, group.activityIdentifiers.contains(where: { $0 == taskPath.identifier })
            else {
                return false
        }
        let activities = Set(finishedSchedules.compactMap { $0.activityIdentifier }).union([taskPath.identifier])
        return activities.count == totalActivitiesCount
    }
    
    /// Total number of activities
    public var totalActivitiesCount : Int {
        return (activityGroup?.activityIdentifiers.count ?? 1)
    }
    
    /// Subset of the finished schedules.
    public private(set) var finishedSchedules: [SBBScheduledActivity] = []
    
    /// Subset of the past survey schedules that were not finished on the day they were scheduled.
    public private(set) var pastSurveySchedules: [SBBScheduledActivity] = []
    
    /// The completion task to use for today.
    public private(set) var todayCompletionTask: StudyBurstConfiguration.CompletionTask?
    
    /// The action bar item to display.
    public var actionBarItem: TodayActionBarItem? {
        guard let schedule = self.getUnfinishedSchedule() else { return nil }
        return TodayActionBarItem(title: schedule.activity.label, detail: schedule.activity.labelDetail, icon: nil)
    }
    
    /// Is there something to do **today** for this study burst? This should return `true` if and only if
    /// this is a "Study Burst" day (`hasStudyBurst == true`) or there is a past schedule that is unfinished.
    public var hasActiveStudyBurst : Bool {
        return self.hasStudyBurst || self.pastSurveySchedules.count > 0
    }
    
    public var shouldShowActionBar : Bool {
        return !self.isCompletedForToday || (self.getUnfinishedSchedule() != nil)
    }
    
    /// Returns an ordered set of task info objects. This will change each day, but should retain the saved
    /// order for any given day.
    public var orderedTasks: [RSDTaskInfo] {
        // Look in-memory first.
        let now = today()
        if let orderedTasks = _orderedTasks,
            let timestamp = _shuffleTimestamp, Calendar.current.isDate(timestamp, inSameDayAs: now) {
            return orderedTasks
        }
        
        guard let tasks = self.activityGroup?.tasks else {
            return []
        }

        if let storedOrder = UserDefaults.standard.array(forKey: StudyBurstScheduleManager.orderKey) as? [String],
            let timestamp = UserDefaults.standard.object(forKey: StudyBurstScheduleManager.timestampKey) as? Date,
            Calendar.current.isDate(timestamp, inSameDayAs: now) {
            // If the timestamp is still valid for today, then sort using the stored order.
            _orderedTasks = tasks.sorted(by: {
                guard let idx1 = storedOrder.index(of: $0.identifier),
                    let idx2 = storedOrder.index(of: $1.identifier)
                    else {
                        return false
                }
                return idx1 < idx2
            })
            _shuffleTimestamp = timestamp
        }
        else {
            // Otherwise, shuffle the tasks and store order of the the task identifiers.
            var shuffledTasks = tasks
            shuffledTasks.shuffle()
            let sortOrder = shuffledTasks.map { $0.identifier }
            _shuffleTimestamp = today()
            _orderedTasks = shuffledTasks
            StudyBurstScheduleManager.setOrderedTasks(sortOrder, timestamp: _shuffleTimestamp!)
        }
        
        return _orderedTasks!
    }
    private var _orderedTasks: [RSDTaskInfo]?
    private var _shuffleTimestamp: Date?
    
    static let orderKey = "StudyBurstTaskOrder"
    static let timestampKey = "StudyBurstTimestamp"
    
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
    
    public func isEngagement(_ taskPath: RSDTaskPath) -> Bool {
        return taskPath.identifier == self.studyBurst.motivationIdentifier ||
            taskPath.identifier == kCompletionTaskIdentifier
    }
    
    public func engagementTaskPath() -> RSDTaskPath? {
        
        // Exit early if the motivation task hasn't been shown.
        if let taskPath = self.motivationTaskPath() {
            return taskPath
        }
        
        // Only return something if this is during the study burst or there is a task that chases you.
        guard self.todayCompletionTask != nil || self.pastSurveySchedules.count > 0
            else {
                return nil
        }
        
        func step(schedule: SBBScheduledActivity) -> RSDStep? {
            guard let activityReference = schedule.activity.activityReference else { return nil }
            if let step = activityReference as? RSDStep {
                return step
            }
            else if let transformer = activityReference as? RSDTaskTransformer {
                return RSDTaskInfoStepObject(with: activityReference, taskTransformer: transformer)
            }
            else {
                return nil
            }
        }
        
        // Add the steps for past tasks that weren't completed and today's tasks.
        var steps: [RSDStep] = pastSurveySchedules.compactMap { step(schedule: $0) }
        
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
        if self.dayCount == 1, self.finishedSchedules.count == 0 {
            task.shouldHideActions = [.navigation(.cancel)]
        }
        
        let path = self.instantiateTaskPath(for: task)
        return path.taskPath
    }
    
    func motivationTaskPath() -> RSDTaskPath? {
        guard !self.hasCompletedMotivationSurvey,
            let transformer = self.configuration.instantiateTaskTransformer(for: self.studyBurst.motivationIdentifier.moduleIdentifier) as? SBASurveyLoader
            else {
                return nil
        }
        return self.instantiateTaskPath(for: transformer.surveyReference as RSDTaskInfo).taskPath
    }
    
    func getTodayCompletionSchedules() -> [SBBScheduledActivity] {
        guard let todayTask = self.todayCompletionTask, self.isCompletedForToday else { return [] }
        return todayTask.activityIdentifiers.compactMap { (activityIdentifier) in
            let taskPredicate = SBBScheduledActivity.activityIdentifierPredicate(with: activityIdentifier.stringValue)
            let schedulePredicate = SBBScheduledActivity.notFinishedAvailableNowPredicate()
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [taskPredicate, schedulePredicate])
            return self.scheduledActivities.first(where: { predicate.evaluate(with: $0) })
        }
    }
    
    func loadIfNeeded() {
        guard self.scheduledActivities.count == 0 else { return }
        
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
            let schedules = self.scheduledActivities
            let (filtered, startedOn, finishedOn) = self.filterFinishedSchedules(schedules)
            self.finishedSchedules = filtered
            if studyMarker.isCompleted {
                self._expiresOn = nil
            }
            else {
                if self.totalActivitiesCount == filtered.count, let finishedOn = finishedOn {
                    self.markCompleted(studyMarker: studyMarker, startedOn: startedOn, finishedOn: finishedOn, finishedSchedules: finishedSchedules)
                }
                else {
                    self._expiresOn = finishedOn?.addingTimeInterval(expiresLimit)
                }
            }
        }
        else {
            self.hasStudyBurst = false
            self._expiresOn = nil
            self.dayCount = nil
        }
        
        self.updateCompletionTask()
        self.updateNotifications()
        
        super.didUpdateScheduledActivities(from: previousActivities)
    }
    
    override func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        
        // Mark the moviation study as completed. This will be stored for future runs to avoid a potential
        // race condition of displaying the "Today" view before the schedules have finished loading.
        if taskPath.identifier == self.studyBurst.motivationIdentifier {
            self.hasCompletedMotivationSurvey = true
        }
        
        // Preload the finished tasks so that the progress will update properly.
        if let schedule = self.scheduledActivity(for: taskPath.result, scheduleIdentifier: taskPath.scheduleIdentifier),
            let activityIdentifier = schedule.activityIdentifier,
            !self.finishedSchedules.contains(where: { $0.activityIdentifier == activityIdentifier}) {
            
            var schedules = self.finishedSchedules
            schedule.startedOn = taskPath.result.startDate
            schedule.finishedOn = taskPath.result.endDate
            schedules.append(schedule)
            let (filtered, _, finishedOn) = self.filterFinishedSchedules(schedules)
            if filtered.count != self.finishedSchedules.count {
                self.finishedSchedules = filtered
                self._expiresOn = finishedOn?.addingTimeInterval(self.expiresLimit)
            }
        }
        super.taskController(taskController, readyToSave: taskPath)
    }
    
    /// Override isCompleted to only return true if the schedule is within the expiration window.
    override func isCompleted(for taskInfo: RSDTaskInfo, on date: Date) -> Bool {
        guard Calendar.current.isDate(date, inSameDayAs: today()) else {
            return super.isCompleted(for: taskInfo, on: date)
        }
        return self.finishedSchedules.first(where: { $0.activityIdentifier == taskInfo.identifier }) != nil
    }
    
    /// Swallow the message for updated schedules if this is the study burst that we just marked as completed.
    override func willSendUpdatedSchedules(for schedules: [SBBScheduledActivity]) {
        guard schedules.count > 1 || schedules.first?.activityIdentifier != self.studyBurst.identifier
            else {
                return
        }
        super.willSendUpdatedSchedules(for: schedules)
    }
    
    func markCompleted(studyMarker: SBBScheduledActivity, startedOn: Date?, finishedOn: Date, finishedSchedules: [SBBScheduledActivity]) {
        
        self._expiresOn = nil
        studyMarker.startedOn = startedOn ?? today()
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
            var json: [String : Any] = [ "taskOrder" : self.orderedTasks.map { $0.identifier }.joined(separator: ",")]
            finishedSchedules.forEach {
                guard let identifier = $0.activityIdentifier, let finishedOn = $0.finishedOn else { return }
                json["\(identifier).startDate"] = ($0.startedOn ?? today()).jsonObject()
                json["\(identifier).endDate"] = finishedOn.jsonObject()
                json["\(identifier).scheduleGuid"] = $0.guid
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
            self.dayCount = dayCount
            self.missedDaysCount = missedDaysCount
        }
        else {
            self.dayCount = nil
            self.missedDaysCount = 0
        }
        self.hasStudyBurst = hasStudyBurst
        
        return studyMarker
    }
    
    /// What is the start of the expiration time window?
    func startTimeWindow() -> Date {
        return today().addingTimeInterval(-1 * expiresLimit)
    }
    
    /// Get the filtered list of finished schedules.
    func filterFinishedSchedules(_ schedules: [SBBScheduledActivity], gracePeriod: TimeInterval = 0) -> ([SBBScheduledActivity], startedOn: Date?, finishedOn: Date?) {
        let taskIds = self.activityGroup?.activityIdentifiers.map { $0.stringValue }
        guard let activityIdentifiers = taskIds
            else {
                return ([], nil, nil)
        }
        
        let calendar = Calendar(identifier: .iso8601)
        let now = today()
        var taskSchedules = [SBBScheduledActivity]()
        var finishedOn : Date?
        var startedOn : Date?
        schedules.forEach { (schedule) in
            guard let activityId = schedule.activityIdentifier,
                activityIdentifiers.contains(activityId),
                let scheduleFinished = schedule.finishedOn,
                calendar.isDate(scheduleFinished, inSameDayAs: now)
                else {
                    return
            }
            let isNewer = !taskSchedules.contains(where: {
                $0.finishedOn! > schedule.finishedOn! &&
                $0.activityIdentifier == schedule.activityIdentifier
            })
            guard isNewer else { return }
            taskSchedules.remove { $0.activityIdentifier == schedule.activityIdentifier }
            taskSchedules.append(schedule)
            if (finishedOn == nil) || (finishedOn! < scheduleFinished) {
                finishedOn = scheduleFinished
                startedOn = schedule.startedOn
            }
        }
        
        // If all the tasks are not finished then remove the ones that are outside the 1 hour window.
        if taskSchedules.count < activityIdentifiers.count {
            let startWindow = startTimeWindow().addingTimeInterval(-1 * gracePeriod)
            taskSchedules.remove { $0.finishedOn! < startWindow }
        }
        
        return (taskSchedules, startedOn, finishedOn)
    }
    
    func calculateThisDay() -> Int {
        guard hasStudyBurst else { return self.maxDaysCount + 1 }
        return self.isLastDay ? self.numberOfDays : ((self.pastDaysCount - self.missedDaysCount) + 1)
    }
    
    func updateCompletionTask() {
        
        // Look for the most appropriate completion tasks for today.
        let thisDay = calculateThisDay()
        let pastTasks = self.getPastTasks(for: thisDay)
        
        self.pastSurveySchedules = getPastSurveySchedules(from: pastTasks)
        self.todayCompletionTask = getTodayCompletionTask(for: thisDay)
    }
    
    func getPastTasks(for thisDay: Int) -> [StudyBurstConfiguration.CompletionTask] {
        return self.studyBurst.completionTasks.filter {
            return $0.day < thisDay
        }
    }
    
    func getPastSurveySchedules(from pastTasks: [StudyBurstConfiguration.CompletionTask]) -> [SBBScheduledActivity] {
        return pastTasks.flatMap { (task) -> [SBBScheduledActivity] in
            let predicate = task.unfinishedPredicate()
            let schedules = self.scheduledActivities.filter { predicate.evaluate(with: $0) }
            guard schedules.count > 0 else { return [] }
            return schedules.sorted(by: { (lhs, rhs) in
                let lIdx = task.activityIdentifiers.index(where: { lhs.activityIdentifier == $0.stringValue }) ?? Int.max
                let rIdx = task.activityIdentifiers.index(where: { rhs.activityIdentifier == $0.stringValue }) ?? Int.max
                return lIdx < rIdx
            })
        }
    }
    
    func getTodayCompletionTask(for thisDay: Int) -> StudyBurstConfiguration.CompletionTask? {
        return self.studyBurst.completionTasks.first(where: { $0.day == thisDay})
    }
    
    func getUnfinishedSchedule() -> SBBScheduledActivity? {
        // Only return the "unfinished" schedule if there is a past schedule that is following the user or
        // else the user has completed their study burst activities for today.
        guard self.pastSurveySchedules.count > 0 || self.isCompletedForToday
            else {
                return nil
        }
        
        let task: StudyBurstConfiguration.CompletionTask? = {
            if self.pastSurveySchedules.count > 0 {
                let thisDay = calculateThisDay()
                let pastTasks = self.getPastTasks(for: thisDay)
                return pastTasks.first(where: { (task) -> Bool in
                    let predicate = task.unfinishedPredicate()
                    return self.scheduledActivities.contains(where: { predicate.evaluate(with: $0) })
                })
            }
            else {
                return self.todayCompletionTask
            }
        }()

        guard let completeTask = task,
            let scheduleIdentifer = self.studyBurst.scheduleIdentifier(for: completeTask)
            else {
                return nil
        }

        let schedules = self.scheduledActivities.filter {
            $0.activityIdentifier == scheduleIdentifer.stringValue
        }
        
        guard schedules.count == 1, let schedule = schedules.first, !schedule.isCompleted
            else {
                return self.pastSurveySchedules.first
        }
        return schedule
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

    func getReminderTime() -> DateComponents? {
        guard let schedule = self.scheduledActivities.first(where: {
            $0.activityIdentifier == RSDIdentifier.studyBurstReminder.stringValue }),
            let clientData = schedule.clientData else {
                return nil
        }
        
        let notificationResult: NotificationResult
        do {
            notificationResult = try SBAFactory.shared.createJSONDecoder().decode(NotificationResult.self, from: clientData)
        } catch let err {
            debugPrint("Failed to decode the reminder result. \(err)")
            return nil
        }
        
        guard !(notificationResult.noReminder ?? false),
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
        if futureSchedules.count <= extraDays {
            let taskPredicate = SBBScheduledActivity.activityIdentifierPredicate(with: self.studyBurst.identifier)
            let start = startOfToday.addingNumberOfDays(2 * extraDays)
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
                debugPrint("Failed to get cached schedules. \(err)")
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
        content.body = "Time to do your mPower Study Burst activities!"
        content.sound = UNNotificationSound.default()
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
}

extension Array {
    
    mutating public func shuffle() {
        var last = self.count - 1
        while last > 0 {
            let rand = Int(arc4random_uniform(UInt32(last)))
            self.swapAt(last, rand)
            last -= 1
        }
    }
    
    public func randomElement() -> Element? {
        guard self.count > 1 else { return self.first }
        let rand = Int(arc4random_uniform(UInt32(self.count)))
        return self[rand]
    }
}
