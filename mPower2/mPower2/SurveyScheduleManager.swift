//
//  SurveyScheduleManager.swift
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


class SurveyScheduleManager : SBAScheduleManager {
    
    /// The configuration is set up either by the bridge configuration or using defaults defined internally.
    lazy var studyBurst: StudyBurstConfiguration! = {
        return (SBABridgeConfiguration.shared as? MP2BridgeConfiguration)?.studyBurst ?? StudyBurstConfiguration()
    }()
    
    var hasSurvey : Bool {
        return scheduledActivities.count > 0
    }
    
    override func fetchRequests() -> [SBAScheduleManager.FetchRequest] {
        
        // TODO: syoung 05/18/2018 Unit test this for accuracy.
        
        var excludeTaskGroupIdentifiers = Set<String>()
        self.configuration.allActivityGroups().forEach {
            guard $0.identifier != self.identifier else { return }
            excludeTaskGroupIdentifiers.formUnion($0.activityIdentifiers.map { $0.stringValue })
        }
        excludeTaskGroupIdentifiers.formUnion(self.studyBurst.completionTaskIdentifiers.map { $0.stringValue})
        excludeTaskGroupIdentifiers.insert(RSDIdentifier.withdrawal.stringValue)
        
        let taskPredicate = NSPredicate(format: "(activity.survey != nil) AND NOT(activity.survey.identifier IN %@)", excludeTaskGroupIdentifiers)
        let notFinishedPredicate = NSCompoundPredicate(notPredicateWithSubpredicate: SBBScheduledActivity.isFinishedPredicate())
        let availableTodayPredicate = SBBScheduledActivity.availableTodayPredicate()
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notFinishedPredicate, availableTodayPredicate, taskPredicate])
        
        return [FetchRequest(predicate: predicate, sortDescriptors: nil, fetchLimit: nil)]
    }
}
