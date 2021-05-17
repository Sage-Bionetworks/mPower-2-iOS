//
//  TaskGroupScheduleManager.swift
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
import BridgeAppUI
import DataTracking
import CardiorespiratoryFitness

let kActivityTrackingIdentifier = "ActivityTracking"
let kMedicationTimingKey = "medicationTiming"
let kMedicationTimingWindow : TimeInterval = 20 * 60

class ScheduledTask : NSObject {
    
    let taskInfo: RSDTaskInfo
    var startedOn: Date?
    var finishedOn: Date?
    var scheduleGuid: String?
    
    init(taskInfo: RSDTaskInfo) {
        self.taskInfo = taskInfo
    }
    
    var identifier: String {
        return taskInfo.identifier
    }
    
    override var description: String {
        return "\(identifier): \(String(describing: finishedOn))"
    }
}

public class ActivityGroupScheduleManager : SBAScheduleManager {
    
    public static let SHOW_HEART_SNAPSHOT_DATA_GROUP = "show_heartsnapshot"
    
    /// List of the tasks including when the task was last finished. Returns `nil` if this is not a
    /// measurement task.
    var orderedTasks: [ScheduledTask] {
        // If the ordered tasks are nil or empty, we never retrieved them properly,
        // as there should always be 3 measuring tasks
        if _orderedTasks == nil || _orderedTasks.isEmpty || shouldRefreshTasks {
            guard let tasks = self.activityGroup?.tasks else {
                debugPrint("WARNING! No tasks are in the activity group.")
                return []
            }
            
            // Order the tasks
            let storedOrder = taskSortOrder
            _orderedTasks = storedOrder.compactMap { (identifier) -> ScheduledTask? in    
                guard let taskInfo = tasks.first(where: { $0.identifier == identifier }) else { return nil }
                return ScheduledTask(taskInfo: taskInfo)
            }
            refreshOrderedTasks()
        }
        return _orderedTasks
    }
    private var _orderedTasks: [ScheduledTask]!
    
    open var shouldShowHeartSnapshot: Bool {
        return self.participant?.dataGroups?.contains(
            TaskGroupScheduleManager.SHOW_HEART_SNAPSHOT_DATA_GROUP) ?? false
    }
    
    /// Should the tasks be refreshed?
    var shouldRefreshTasks: Bool {
        return false
    }
    
    /// Returns Date(). Included for testing.
    func today() -> Date {
        return Date()
    }
    
    /// The order of the tasks.
    var taskSortOrder: [String] {
        return self.activityGroup?.activityIdentifiers.map { $0.stringValue } ?? []
    }
    
    func refreshOrderedTasks() {
        let schedules: [SBBScheduledActivity] = {
            if self.scheduledActivities.count > 0 {
                return self.scheduledActivities
            }
            else if let group = activityGroup {
                do {
                    let todayPredicate = SBBScheduledActivity.availableOnPredicate(on: today())
                    let tasksPredicate = SBBScheduledActivity.activityGroupPredicate(for: group)
                    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [todayPredicate, tasksPredicate])
                    return try self.activityManager.getCachedSchedules(using: predicate, sortDescriptors: nil, fetchLimit: 0)
                } catch let err {
                    print("WARNING! Failed to get cached schedules: \(err)")
                    return []
                }
            }
            else {
                assertionFailure("This schedule manager requires having the task group set.")
                return []
            }
        }()
        let now = today()
        _orderedTasks?.forEach { (scheduledTask) in
            let finishedSchedule = schedules.first(where: {
                if let finishedOn = $0.finishedOn,
                    $0.activityIdentifier == scheduledTask.identifier,
                    Calendar.iso8601.isDate(finishedOn, inSameDayAs: now) {
                    return true
                }
                else {
                    return false
                }
            })
    
            if let schedule = finishedSchedule {
                // Look first to see if there is a schedule for this task.
                scheduledTask.scheduleGuid = schedule.guid
                scheduledTask.startedOn = schedule.startedOn ?? schedule.finishedOn
                scheduledTask.finishedOn = schedule.finishedOn
            }
            else if let report = self.report(with: scheduledTask.identifier),
                Calendar.iso8601.isDate(report.date, inSameDayAs: today()) {
                // If a schedule isn't found, then look for a report.
                scheduledTask.finishedOn = report.date
                scheduledTask.startedOn = report.date
            }
        }
    }
    
    override public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // Mark the scheduled task start and end date.
        if let (scheduledTask, taskResult) = scheduledTask(for: taskViewModel) {
            scheduledTask.startedOn = taskResult.startDate
            scheduledTask.finishedOn = taskResult.endDate
        }
        if (taskController.task.identifier == RSDIdentifier.heartSnapshotTask.identifier) {
            StudyBurstScheduleManager.shared.saveLastHeartSnapshotFininshedDate()
        }
        super.taskController(taskController, readyToSave: taskViewModel)
    }
    
    func scheduledTask(for taskViewModel: RSDTaskViewModel) -> (ScheduledTask, RSDTaskResult)? {
        guard let scheduledTask = self.orderedTasks.first(where: { $0.identifier == taskViewModel.identifier })
            else {
                return nil
        }
        return (scheduledTask, taskViewModel.taskResult)
    }
}

public class TrackingScheduleManager : ActivityGroupScheduleManager {
    
    override open func reportQueries() -> [ReportQuery] {
        let tasks: [RSDIdentifier] = [.triggersTask, .symptomsTask, .medicationTask]
        return tasks.map { ReportQuery(reportKey: $0, queryType: .mostRecent, dateRange: nil) }
    }
}

public class TaskGroupScheduleManager : ActivityGroupScheduleManager {
    
    var _medicationTimingResult : RSDAnswerResult?
    
    var shouldIncludeMedicationTiming : Bool {
        guard (self.participant?.dataGroups?.contains("parkinsons") ?? false)
            else {
                return false
        }
        if let timingResult = _medicationTimingResult,
            timingResult.startDate.timeIntervalSinceNow < kMedicationTimingWindow {
            return false
        }
        else {
            return true
        }
    }
    
    open override func report(with activityIdentifier: String) -> SBAReport? {
        if (activityIdentifier == RSDIdentifier.heartSnapshotTask.identifier) {
            return createCRFTaskData()
        }
        return super.report(with: activityIdentifier)
    }
    
    override public func instantiateTaskViewModel(for taskInfo: RSDTaskInfo, in activityGroup: SBAActivityGroup? = nil) -> (taskViewModel: RSDTaskViewModel, referenceSchedule: SBBScheduledActivity?) {
        
        guard isMeasurementTaskIdentifier(taskInfo.identifier)
            else {
                return super.instantiateTaskViewModel(for: taskInfo, in: activityGroup)
        }
        
        // If they haven't ever set the passive data permissions flag, and this is
        // the walking task, insert the passive data permission step just after they
        // complete the task.
        var passiveDataPermissionStep: RSDSubtaskStepObject? = nil
        if taskInfo.identifier == .walkAndBalanceTask,
                SBAProfileManagerObject.shared.value(forProfileKey: RSDIdentifier.passiveDataPermissionProfileKey.rawValue) == nil {
            let passiveInfo = RSDTaskInfoObject(with: RSDIdentifier.passiveDataPermission.rawValue)
            let passiveInfoStep = RSDTaskInfoStepObject(with: passiveInfo)
            let navSteps = [passiveInfoStep]
            var navigator = RSDConditionalStepNavigatorObject(with: navSteps)
            navigator.progressMarkers = []
            let passiveDataPermissionTask = RSDTaskObject(identifier: RSDIdentifier.passiveDataPermission.rawValue, stepNavigator: navigator)
            passiveDataPermissionStep = RSDSubtaskStepObject(task: passiveDataPermissionTask)
        }
        
        if self.shouldIncludeMedicationTiming {
            // Override the base implementation to insert the tracking step.
            let taskInfoStep = RSDTaskInfoStepObject(with: taskInfo)
            let trackingInfo = RSDTaskInfoObject(with: kActivityTrackingIdentifier)
            let trackingStep = RSDTaskInfoStepObject(with: trackingInfo)
            var navSteps: [RSDStep] = [trackingStep, taskInfoStep]
            
            do {
                let medsTask: RSDTask = try self.task(with: .medicationTask)
                let medsStep = try SBAMedicationTrackingStep(mainTask: medsTask)
                navSteps.insert(medsStep, at: 0)
            }
            catch let err {
                assertionFailure("Failed to create the medication tracking step. \(err)")
            }
            
            // Tack on the passive data permission step too, if need be.
            if let permStep = passiveDataPermissionStep {
                navSteps.append(permStep)
            }
            
            var navigator = RSDConditionalStepNavigatorObject(with: navSteps)
            navigator.progressMarkers = []
            let task = RSDTaskObject(identifier: taskInfo.identifier, stepNavigator: navigator)
            
            // Return a task path that includes both.
            return self.instantiateTaskViewModel(for: task)
        }
        else {
            // If there's a passive data permission step, bundle it on to the taskInfo
            // step with a step navigator. Otherwise just use the taskInfo step.
            var ret: (taskViewModel: RSDTaskViewModel, referenceSchedule: SBBScheduledActivity?)!
            if let permStep = passiveDataPermissionStep {
                let taskInfoStep = RSDTaskInfoStepObject(with: taskInfo)
                let navSteps: [RSDStep] = [taskInfoStep, permStep]
                
                var navigator = RSDConditionalStepNavigatorObject(with: navSteps)
                navigator.progressMarkers = []
                let task = RSDTaskObject(identifier: taskInfo.identifier, stepNavigator: navigator)
                
                ret = self.instantiateTaskViewModel(for: task)
            } else {
                ret = super.instantiateTaskViewModel(for: taskInfo, in: activityGroup)
            }
            
            // Now add the medication timing result to the async results.
            if let medResult = _medicationTimingResult {
                ret.taskViewModel.taskResult.appendAsyncResult(with: medResult)
            }
            return ret
        }
    }
    
    override public func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
        // Look for the medication timing question and store in memory.
        if let result = taskViewModel.taskResult.findAnswerResult(with: kMedicationTimingKey) {
            _medicationTimingResult = result
        }
        if (taskController.task.identifier == RSDIdentifier.heartSnapshotTask.identifier) {
            StudyBurstScheduleManager.shared.saveLastHeartSnapshotFininshedDate()
        }
        super.taskController(taskController, readyToSave: taskViewModel)
    }
    
    public func answerKey(for resultIdentifier: String, with sectionIdentifier: String?) -> String? {
        guard sectionIdentifier == kActivityTrackingIdentifier || isMeasurementTaskIdentifier(sectionIdentifier)
            else {
                return nil
        }
        return resultIdentifier
    }
    
    override public func buildClientData(from taskResult: RSDTaskResult) -> SBBJSONValue? {
        let clientData = super.buildClientData(from: taskResult)
        guard let dict = clientData as? [String : Any],
            self.isMeasurementTaskIdentifier(taskResult.identifier) else {
                return clientData
        }
        
        var json = dict
        if let medResult = taskResult.findAnswerResult(with: kMedicationTimingKey) ?? _medicationTimingResult,
            let medTiming = medResult.value {
            json[kMedicationTimingKey] = medTiming
        }
        
        return json as NSDictionary
    }
    
    func isMeasurementTaskIdentifier(_ identifier: String?) -> Bool {
        guard identifier != nil else { return false }
        let rsdIdentifer = RSDIdentifier(rawValue: identifier!)
        return RSDIdentifier.measuringTasks.contains(rsdIdentifer)
    }
    
    override open func reportQueries() -> [ReportQuery] {
        let tasks: [RSDIdentifier] = [.medicationTask, .tremorTask, .tappingTask, .walkAndBalanceTask]
        return tasks.map { ReportQuery(reportKey: $0, queryType: .mostRecent, dateRange: nil) }
    }
    
    /// Returns the birth year and sex answer results ready to be added as previous results to a task
    func createCRFTaskData() -> SBAReport? {
        // Must have both birthYear and sex to create the CRF task data
        if let yearAnswerStr = SBAProfileDataSourceObject.shared.profileTableItem(at: ProfileTableViewController.birthYearIndexPath)?.detail,
           let yearInt = Int(yearAnswerStr),
           let sexAnswerStr = SBAProfileDataSourceObject.shared.profileTableItem(at: ProfileTableViewController.sexIndexPath)?.detail {
            
            let json = [CRFDemographicsKeys.sex.stringValue : sexAnswerStr,
                        CRFDemographicsKeys.birthYear.stringValue : yearInt] as RSDJSONSerializable
            
            return SBAReport(identifier: RSDIdentifier.heartSnapshotTask.identifier, date: Date(), json: json)
        }
        
        return nil
    }
}

struct CRFTaskData: RSDTaskData {
    var identifier: String
    var timestampDate: Date?
    var json: RSDJSONSerializable
}

extension SBAReportManager {
    
    /// Get the task with the given identifier.
    func task(with taskIdentifier: RSDIdentifier) throws -> RSDTask {
        return try {
            if let task = self.configuration.task(for: taskIdentifier.rawValue) {
                return task
            }
            else {
                let transformer = RSDResourceTransformerObject(resourceName: taskIdentifier.rawValue)
                return try self.factory.decodeTask(with: transformer)
            }
        }()
    }
    
    /// Tracked items for this task.
    func trackedItems(with taskIdentifier: RSDIdentifier) throws -> [SBATrackedItem] {
        let task = try self.task(with: taskIdentifier)
        guard let navigator = task.stepNavigator as? SBATrackedItemsStepNavigator
            else {
                throw RSDValidationError.invalidType("The step navigator could not be transformed into a tracking navigator.")
        }
        return navigator.items
    }
}
