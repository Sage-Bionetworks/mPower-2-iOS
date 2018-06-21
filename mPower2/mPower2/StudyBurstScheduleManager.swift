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

/// The study burst navigator is a work-around for including a Decodable in the `AppConfig.clientData` without
/// having to redesign how the SBABridgeConfiguration works to include objects decoded with a factory.
/// TODO: syoung 06/19/2018 Refactor this to use a decodable object with a type.
public struct StudyBurstConfiguration : Codable {
    
    private enum CodingKeys : String, CodingKey {
        case identifier, numberOfDays, minimumRequiredDays, expiresLimit, taskGroupIdentifier, completionTasks, engagementDataGroups
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
    
    /// The completion tasks for each day of the study burst.
    let completionTasks: [CompletionTask]
    
    /// List of the possible engagement data groups.
    let engagementDataGroups: [String]?
    
    public init() {
        self.identifier = RSDIdentifier.studyBurstCompletedTask.stringValue
        self.numberOfDays = 14
        self.minimumRequiredDays = 10
        self.expiresLimit = 60 * 60
        self.taskGroupIdentifier = .measuringTaskGroup
        self.completionTasks = [
            CompletionTask(day: 1, firstOnly: true, activityIdentifiers: [.demographics, .studyBurstReminder]),
            CompletionTask(day: 14, firstOnly: true, activityIdentifiers: [.engagement])
        ]
        self.engagementDataGroups = ["engagement_A", "engagement_B"]
    }
    
    struct CompletionTask : Codable {
        let day: Int?
        let firstOnly: Bool?
        let activityIdentifiers: [RSDIdentifier]
    }

    public var completionTaskIdentifiers: [RSDIdentifier] {
        return completionTasks.flatMap { $0.activityIdentifiers }
    }
}

let kCompletionTaskIdentifier: String = "TempStudyBurstCompletionTask"


/// The study burst manager is accessible on the "Today" view as well as being used to manage the study burst
/// view controller.
class StudyBurstScheduleManager : SBAScheduleManager {
    
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
        if expiresOn > Date() {
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
    
    /// Today marker used to update the schedules.
    public private(set) var today: Date?
    
    /// Is the Study burst completed for today?
    public var isCompletedForToday : Bool {
        return !hasStudyBurst || (finishedSchedules.count == totalActivitiesCount)
    }
    
    public func isFinalTask(_ taskPath: RSDTaskPath) -> Bool {
        let activities = Set(finishedSchedules.compactMap { $0.activityIdentifier }).union([taskPath.identifier])
        return activities.count == totalActivitiesCount
    }
    
    /// Total number of activities
    public var totalActivitiesCount : Int {
        return (activityGroup?.activityIdentifiers.count ?? 1)
    }
    
    /// Subset of the finished schedules.
    public private(set) var finishedSchedules: [SBBScheduledActivity] = []
    
    /// Returns an ordered set of task info objects. This will change each day, but should retain the saved
    /// order for any given day.
    public var orderedTasks: [RSDTaskInfo] {
        // Look in-memory first.
        if let orderedTasks = _orderedTasks,
            let timestamp = _shuffleTimestamp, Calendar.current.isDateInToday(timestamp) {
            return orderedTasks
        }
        
        guard let tasks = self.activityGroup?.tasks else {
            return []
        }

        let userDefaults = UserDefaults.standard
        let orderKey = "StudyBurstTaskOrder"
        let timestampKey = "StudyBurstTimestamp"
        
        
        if let storedOrder = userDefaults.array(forKey: orderKey) as? [String],
            let timestamp = userDefaults.object(forKey: timestampKey) as? Date,
            Calendar.current.isDateInToday(timestamp) {
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
            _orderedTasks = shuffledTasks
            _shuffleTimestamp = Date()
            let sortOrder = shuffledTasks.map { $0.identifier }
            userDefaults.set(sortOrder, forKey: orderKey)
            userDefaults.set(_shuffleTimestamp, forKey: timestampKey)
        }
        
        return _orderedTasks!
    }
    private var _orderedTasks: [RSDTaskInfo]?
    private var _shuffleTimestamp: Date?
    
    public var isLastDay: Bool {
        guard let _ = self.dayCount, self.hasStudyBurst else { return false }
        let days = (self.pastDaysCount - self.missedDaysCount) + 1
        return (self.maxDaysCount == days) || (self.numberOfDays == days)
    }
    
    public func completionTaskPath() -> RSDTaskPath? {

        // Look for the most appropriate completion tasks for today.
        let thisDay = self.isLastDay ? self.numberOfDays : ((self.pastDaysCount - self.missedDaysCount) + 1)
        let pastTasks = self.studyBurst.completionTasks.filter {
            guard let day = $0.day, day < thisDay else { return false }
            return ($0.firstOnly ?? false)
        }
        
        // Only return something if the marked day is
        guard self.hasStudyBurst || pastTasks.count > 0
            else {
                return nil
        }
        
        // If there are any past tasks, look for matching schedules where none are finished.
        let pastSchedules: [SBBScheduledActivity] = pastTasks.flatMap { (task) -> [SBBScheduledActivity] in
            return task.activityIdentifiers.compactMap { (identifier) -> SBBScheduledActivity? in
                let schedules = self.scheduledActivities.filter { $0.activityIdentifier == identifier.stringValue }
                return schedules.contains(where: { $0.isCompleted }) ? nil : schedules.first
            }
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
        
        func step(activityIdentifier: RSDIdentifier) -> RSDStep? {
            // Otherwise, look for a transformer in the configuration.
            guard let transformer = self.configuration.instantiateTaskTransformer(for: activityIdentifier.moduleIdentifier)
                else {
                    return nil
            }
            
            // And create a task info step if found.
            let taskInfo = RSDTaskInfoObject(with: activityIdentifier.rawValue)
            return RSDTaskInfoStepObject(with: taskInfo, taskTransformer: transformer)
        }
        
        // Add the steps for past tasks that weren't completed and today's tasks.
        var steps: [RSDStep] = pastSchedules.compactMap { step(schedule: $0) }
        
        func addSteps(for task: StudyBurstConfiguration.CompletionTask) {
            let firstOnly = task.firstOnly ?? false
            task.activityIdentifiers.forEach { (activityIdentifier) in
                let schedule = self.scheduledActivities.filter {
                    $0.activityIdentifier == activityIdentifier.stringValue &&
                    (!firstOnly || !$0.isCompleted)
                    }.sorted(by: { $0.scheduledOn < $1.scheduledOn }).last
                guard !firstOnly || (schedule != nil) else { return }
                
                // Look for a step
                if !steps.contains(where: { $0.identifier == activityIdentifier.stringValue }),
                    let step: RSDStep = (schedule != nil) ? step(schedule: schedule!) : step(activityIdentifier: activityIdentifier) {
                    steps.append(step)
                }
            }
        }
        

        if let todayOnlyTask = self.studyBurst.completionTasks.first(where: { $0.day == thisDay}) {
            addSteps(for: todayOnlyTask)
        }
        else if steps.count == 0, let foundTask = self.studyBurst.completionTasks.first(where: { $0.day == nil }) {
            addSteps(for: foundTask)
        }

        // If there aren't any steps then return nil.
        guard steps.count > 0 else { return nil }
        
        // Finally, create a task to run the returned steps.
        let navigator = RSDConditionalStepNavigatorObject(with: steps)
        let task = RSDTaskObject(identifier: kCompletionTaskIdentifier, stepNavigator: navigator)
        return self.instantiateTaskPath(for: task).taskPath
    }
    
    /// Override to get past 14 days of study burst markers and today's activities.
    override func fetchRequests() -> [SBAScheduleManager.FetchRequest] {
        guard let group = self.activityGroup else {
            return super.fetchRequests()
        }

        // Build a predicate with today's tasks and all the completion tasks available today.
        let completionTaskIdentifiers = self.studyBurst.completionTaskIdentifiers
        let activityIdentifiers = [group.activityIdentifiers, completionTaskIdentifiers].flatMap { $0 }
        var predicates: [NSPredicate] = activityIdentifiers.map {
            let predicate = SBBScheduledActivity.activityIdentifierPredicate(with:$0.stringValue)
            let start = Date().startOfDay()
            let end = start.addingNumberOfDays(1)
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                SBBScheduledActivity.availablePredicate(from: start, to: end),
                predicate])
        }
        
        // Add the study burst marker
        let predicate = SBBScheduledActivity.activityIdentifierPredicate(with: self.studyBurst.identifier)
        let start = Date().startOfDay().addingNumberOfDays(-2 * self.numberOfDays)
        let end = Date().startOfDay().addingNumberOfDays(2 * self.numberOfDays)
        let studyMarkerPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SBBScheduledActivity.availablePredicate(from: start, to: end),
            predicate])
        predicates.append(studyMarkerPredicate)
        
        let filter = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return [FetchRequest(predicate: filter, sortDescriptors: nil, fetchLimit: nil)]
    }
    
    /// Override to build the new set of today history items.
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        guard (today == nil) || !Calendar.current.isDateInToday(today!) || !isCompletedForToday
            else {
                super.didUpdateScheduledActivities(from: previousActivities)
                return
        }
        today = Date()
        
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

        super.didUpdateScheduledActivities(from: previousActivities)
    }
    
    /// Override isCompleted to only return true if the schedule is within the expiration window.
    override func isCompleted(for taskInfo: RSDTaskInfo, on date: Date) -> Bool {
        guard Calendar.current.isDateInToday(date) else {
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
        studyMarker.startedOn = startedOn ?? Date()
        studyMarker.finishedOn = finishedOn
        
        guard let identifier = studyMarker.activityIdentifier,
            let schemaInfo = studyMarker.schemaInfo else {
                return
        }
        
        do {
        
            // build the archive
            let archive = SBAScheduledActivityArchive(identifier: identifier, schemaInfo: schemaInfo, schedule: studyMarker)
            var json: [String : Any] = [ "taskOrder" : self.orderedTasks.map { $0.identifier }.joined(separator: ",")]
            finishedSchedules.forEach {
                guard let identifier = $0.activityIdentifier, let finishedOn = $0.finishedOn else { return }
                json[identifier] = [
                    "startDate": ($0.startedOn ?? Date()).jsonObject(),
                    "endDate": finishedOn.jsonObject(),
                    "scheduleGuid": $0.guid
                ]
            }
            archive.insertDictionary(intoArchive: json, filename: "tasks", createdOn: finishedOn)
            
            try archive.completeArchive(createdOn: finishedOn, with: nil)
            
            self.offMainQueue.async {
                archive.encryptAndUploadArchive()
            }
        }
        catch let err {
            print("Failed to archive the study burst data. \(err)")
        }
        
        self.sendUpdated(for: [studyMarker])
    }
    
    /// Returns the study burst completed marker for today.
    func getStudyBurst() -> SBBScheduledActivity? {
        
        let studyBurstMarkerId = self.studyBurst.identifier
        guard let studyMarker = self.scheduledActivities.first(where: {
            $0.activityIdentifier == studyBurstMarkerId && Calendar.current.isDateInToday($0.scheduledOn)
        })
            else {
                return nil
        }

        let markerSchedules = self.scheduledActivities.filter { studyMarker.activityIdentifier == $0.activityIdentifier }
        
        let todayStart = Date().startOfDay()
        let pastSchedules = markerSchedules.filter { $0.scheduledOn < todayStart }
        let dayCount = pastSchedules.count + 1
        let missedDaysCount = pastSchedules.reduce(0, { $0 + ($1.finishedOn == nil ? 1 : 0) })
        let finishedCount = dayCount - missedDaysCount
        let hasStudyBurst = (finishedCount <= self.numberOfDays)
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
        return Date().addingTimeInterval(-1 * expiresLimit)
    }
    
    /// Get the filtered list of finished schedules.
    func filterFinishedSchedules(_ schedules: [SBBScheduledActivity], gracePeriod: TimeInterval = 0) -> ([SBBScheduledActivity], startedOn: Date?, finishedOn: Date?) {
        let taskIds = self.activityGroup?.activityIdentifiers.map { $0.stringValue }
        guard let activityIdentifiers = taskIds
            else {
                return ([], nil, nil)
        }
        let startWindow = startTimeWindow().addingTimeInterval(-1 * gracePeriod)
        var finishedOn : Date?
        var startedOn : Date?
        let results = schedules.filter { (schedule) in
            guard let activityId = schedule.activityIdentifier, activityIdentifiers.contains(activityId)
                else {
                    return false
            }
            if let scheduleFinished = schedule.finishedOn, scheduleFinished >= startWindow {
                if (finishedOn == nil) || (finishedOn! < scheduleFinished) {
                    finishedOn = scheduleFinished
                }
                if let scheduleStarted = schedule.startedOn,
                    ((startedOn == nil) || (startedOn! > scheduleStarted)) {
                    startedOn = scheduleStarted
                }
                return true
            }
            else {
                return false
            }
        }
        return (results, startedOn, finishedOn)
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
}
