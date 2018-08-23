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
import BridgeApp

let kActivityTrackingIdentifier = "ActivityTracking"
let kMedicationTimingWindow : TimeInterval = 20 * 60

public class TrackingScheduleManager : SBAScheduleManager {
    
    override open func reportQueries() -> [ReportQuery] {
        let tasks: [RSDIdentifier] = [.triggersTask, .symptomsTask, .medicationTask]
        return tasks.map { ReportQuery(identifier: $0, queryType: .mostRecent, dateRange: nil) }
    }
}

public class TaskGroupScheduleManager : SBAScheduleManager {
    
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
    
    override public func instantiateTaskPath(for taskInfo: RSDTaskInfo, in activityGroup: SBAActivityGroup? = nil) -> (taskPath: RSDTaskPath, referenceSchedule: SBBScheduledActivity?) {
        
        guard isMeasurementTaskIdentifier(taskInfo.identifier),
            let transformer = taskInfo.resourceTransformer ?? configuration.instantiateTaskTransformer(for: taskInfo)
            else {
                return super.instantiateTaskPath(for: taskInfo, in: activityGroup)
        }
        
        if self.shouldIncludeMedicationTiming {
            // Override the base implementation to insert the tracking step.
            let taskInfoStep = RSDTaskInfoStepObject(with: taskInfo, taskTransformer: transformer)
            let trackingTransformer = RSDResourceTransformerObject(resourceName: kActivityTrackingIdentifier)
            let trackingInfo = RSDTaskInfoObject(with: kActivityTrackingIdentifier)
            let trackingStep = RSDTaskInfoStepObject(with: trackingInfo, taskTransformer: trackingTransformer)
            var navigator = RSDConditionalStepNavigatorObject(with: [trackingStep, taskInfoStep])
            navigator.progressMarkers = []
            let task = RSDTaskObject(identifier: taskInfo.identifier, stepNavigator: navigator)
            
            // Return a task path that includes both.
            return self.instantiateTaskPath(for: task)
        }
        else {
            // Add the medication timing result to the async results.
            let ret = super.instantiateTaskPath(for: taskInfo, in: activityGroup)
            if let medResult = _medicationTimingResult {
                ret.taskPath.appendAsyncResult(with: medResult)
            }
            return ret
        }
    }
    
    override public func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        
        // Look for the medication timing question and store in memory.
        if let result = taskPath.result.findAnswerResult(with: "medicationTiming") {
            _medicationTimingResult = result
        }
        super.taskController(taskController, readyToSave: taskPath)
    }
    
    public func answerKey(for resultIdentifier: String, with sectionIdentifier: String?) -> String? {
        guard sectionIdentifier == kActivityTrackingIdentifier || isMeasurementTaskIdentifier(sectionIdentifier)
            else {
                return nil
        }
        return resultIdentifier
    }
    
    func isMeasurementTaskIdentifier(_ identifier: String?) -> Bool {
        guard identifier != nil else { return false }
        let rsdIdentifer = RSDIdentifier(rawValue: identifier!)
        return RSDIdentifier.measuringTasks.contains(rsdIdentifer)
    }
    
    override open func reportQueries() -> [ReportQuery] {
        return [ReportQuery(identifier: .medicationTask, queryType: .mostRecent, dateRange: nil) ]
    }
}
