//
//  DataSourceManager.swift
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
import MotorControl

extension RSDIdentifier {
    
    static let measuringTaskGroup: RSDIdentifier = "Measuring"
    static let trackingTaskGroup: RSDIdentifier = "Tracking"
    static let surveyTaskGroup: RSDIdentifier = "Health Surveys"
    
    static let triggersTask: RSDIdentifier = "Triggers"
    static let symptomsTask: RSDIdentifier = "Symptoms"
    static let medicationTask: RSDIdentifier = "Medication"
    
    static let tappingTask: RSDIdentifier =  MCTTaskIdentifier.tapping.identifier
    static let tremorTask: RSDIdentifier = MCTTaskIdentifier.tremor.identifier
    static let walkAndBalanceTask: RSDIdentifier = MCTTaskIdentifier.walkAndBalance.identifier
    static let measuringTasks: [RSDIdentifier] = [.tappingTask, .tremorTask, .walkAndBalanceTask]
    
    static let studyBurstCompletedTask: RSDIdentifier = "study-burst-task"
    static let demographics: RSDIdentifier = "Demographics"
    static let background: RSDIdentifier = "Background"
    static let engagement: RSDIdentifier = "Engagement"
    static let motivation: RSDIdentifier = "Motivation"
    static let withdrawal: RSDIdentifier = "Withdrawal"
    static let studyBurstReminder: RSDIdentifier = "StudyBurstReminder"
}

extension MCTTaskInfo : SBAActivityInfo {
    
    public var moduleId: SBAModuleIdentifier? {
        return SBAModuleIdentifier(rawValue: self.identifier)
    }
}

extension MCTTaskIdentifier {
    
    public var rsdIdentifier : RSDIdentifier {
        return RSDIdentifier(rawValue: self.rawValue)
    }
}

/// The data source manager is used to allow testing to **not** connect to the Bridge server. It uses a
/// singleton to manage the data sources.
///
/// - note: This singleton assumes that the schedule managers that are created are only instantiated
/// for a signed-in user **or** by the mPower2TestApp.
class DataSourceManager {
    
    let tabs: [RSDIdentifier : [RSDIdentifier]] =
        [ .trackingTaskGroup : [.triggersTask, .symptomsTask, .medicationTask],
          .measuringTaskGroup : MCTTaskIdentifier.all().map { $0.rsdIdentifier }]
    
    let categoryMapping : [RSDIdentifier : SBAReportCategory] = [
        .studyBurstReminder : .singleton,
        .motivation : .singleton,
        .demographics : .singleton,
        .background : .singleton,
        .engagement : .singleton,
        .medicationTask : .groupByDay
    ]
    
    /// Shared singleton
    static let shared = DataSourceManager()
    private init() { }
    
    var configuration : SBABridgeConfiguration {
        return SBABridgeConfiguration.shared
    }
    
    func activityGroup(with identifier: RSDIdentifier) -> SBAActivityGroup? {
        return configuration.activityGroup(with: identifier.stringValue)
    }
    
    func scheduleManager(with identifier: RSDIdentifier) -> SBAScheduleManager {
        installTaskGroupsIfNeeded()
        switch identifier {
        case .measuringTaskGroup:
            let scheduleManager = TaskGroupScheduleManager()
            scheduleManager.activityGroup = activityGroup(with: identifier)
            return scheduleManager
            
        default:
            let scheduleManager = TrackingScheduleManager()
            scheduleManager.activityGroup = activityGroup(with: identifier)
            return scheduleManager
        }
    }
    
    func todayHistoryScheduleManager() -> TodayHistoryScheduleManager {
        installTaskGroupsIfNeeded()
        return TodayHistoryScheduleManager()
    }
    
    func studyBurstScheduleManager() -> StudyBurstScheduleManager {
        installTaskGroupsIfNeeded()
        return StudyBurstScheduleManager.shared
    }
    
    func surveyManager() -> SurveyScheduleManager {
        installTaskGroupsIfNeeded()
        return SurveyScheduleManager()
    }
    
    // MARK: Install the task groups from either the bridge configuration or embedded resources.
    
    private func installTaskGroupsIfNeeded() {
        
        self.categoryMapping.forEach {
            self.configuration.addMapping(with: $0.key.stringValue, to: $0.value)
        }
        
        let installedGroups = configuration.allActivityGroups()
        let rsdIdentifiers: [RSDIdentifier] = [.measuringTaskGroup, .trackingTaskGroup]
        
        rsdIdentifiers.forEach { (groupIdentifier) in
            let installedGroup = installedGroups.first(where: { $0.identifier == groupIdentifier.stringValue })
            
            // Get the activity identifiers.
            guard let activityIdentifiers: [RSDIdentifier] = installedGroup?.activityIdentifiers ??
                tabs[groupIdentifier]
                else {
                    assertionFailure("Missing identifiers for \(groupIdentifier)")
                    return
            }
            
            // Install the group if not already included.
            if installedGroup == nil {
                let groupId = groupIdentifier.stringValue
                let activityGroup = SBAActivityGroupObject(identifier: groupId,
                                                           title: Localization.localizedString(groupId),
                                                           journeyTitle: nil,
                                                           image: nil,
                                                           activityIdentifiers: activityIdentifiers,
                                                           notificationIdentifier: nil,
                                                           schedulePlanGuid: nil,
                                                           activityGuidMap: nil)
                configuration.addMapping(with: activityGroup)
            }
            
            // Check that there is a mapped task info in the bridge configuration.
            activityIdentifiers.forEach { (activityId) in
                
                // If the installed info has an image then it's loaded.
                let installedInfo = configuration.activityInfo(for: activityId.stringValue)
                if installedInfo?.imageVendor != nil {
                    return
                }
                
                // Install the task and task info.
                if let mctIdentifier = MCTTaskIdentifier(rawValue: activityId.stringValue) {
                    let taskInfo = MCTTaskInfo(mctIdentifier)
                    configuration.addMapping(with: taskInfo)
                }
                else {
                    let image = UIImage(named: "\(activityId.stringValue)TaskIcon")
                    let title = installedInfo?.title ?? Localization.localizedString(activityId.stringValue)
                    let moduleId = installedInfo?.moduleId ?? SBAModuleIdentifier(rawValue: activityId.stringValue)
                    let taskInfo = SBAActivityInfoObject(identifier: activityId,
                                                         title: title,
                                                         subtitle: installedInfo?.subtitle,
                                                         detail: installedInfo?.detail,
                                                         estimatedMinutes: installedInfo?.estimatedMinutes,
                                                         iconImage: image,
                                                         resource: nil,
                                                         moduleId: moduleId)
                    configuration.addMapping(with: taskInfo)
                }
            }
        }
    }
    
}
