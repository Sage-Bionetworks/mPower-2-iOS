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
    static let trackingTasks: [RSDIdentifier] = [.triggersTask, .symptomsTask, .medicationTask]
    
    static let tappingTask: RSDIdentifier =  MCTTaskIdentifier.tapping.identifier
    static let tremorTask: RSDIdentifier = MCTTaskIdentifier.tremor.identifier
    static let walkAndBalanceTask: RSDIdentifier = MCTTaskIdentifier.walkAndBalance.identifier
    static let measuringTasks: [RSDIdentifier] = [.tappingTask, .tremorTask, .walkAndBalanceTask]
    
    static let studyBurstCompletedTask: RSDIdentifier = "study-burst-task"
    static let demographics: RSDIdentifier = "Demographics"
    static let engagement: RSDIdentifier = "Engagement"
    static let studyBurstReminder: RSDIdentifier = "StudyBurstReminder"
}

extension MCTTaskInfo : SBAActivityInfo {
    
    public var moduleId: SBAModuleIdentifier? {
        return SBAModuleIdentifier(rawValue: self.identifier)
    }
}

/// The data source manager is used to allow testing to **not** connect to the Bridge server. It uses a
/// singleton to manage the data sources.
///
/// - note: This singleton assumes that the schedule managers that are created are only instantiated
/// for a signed-in user **or** by the mPower2TestApp.
class DataSourceManager {
    
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
        let scheduleManager = SBAScheduleManager()
        scheduleManager.activityGroup = activityGroup(with: identifier)
        return scheduleManager
    }
    
    func todayHistoryScheduleManager() -> TodayHistoryScheduleManager {
        installTaskGroupsIfNeeded()
        return TodayHistoryScheduleManager()
    }
    
    func studyBurstScheduleManager() -> StudyBurstScheduleManager {
        installTaskGroupsIfNeeded()
        return StudyBurstScheduleManager()
    }
    
    func surveyManager() -> SurveyScheduleManager {
        installTaskGroupsIfNeeded()
        return SurveyScheduleManager()
    }
    
    // MARK: Install the task groups from either the bridge configuration or embedded resources.
    
    private var _hasInstalledTaskGroups = false
    private func installTaskGroupsIfNeeded() {
        guard !_hasInstalledTaskGroups else { return }
        _hasInstalledTaskGroups = true
        
        let installedGroups = configuration.installedGroups
        
        let rsdIdentifiers: [RSDIdentifier] = [.measuringTaskGroup, .trackingTaskGroup]
        rsdIdentifiers.forEach { (groupIdentifier) in
            let installedGroup = installedGroups.first(where: { $0.identifier == groupIdentifier.stringValue })
            
            // Get the activity identifiers.
            let activityIdentifiers: [RSDIdentifier] = {
                if installedGroup != nil {
                    return installedGroup!.activityIdentifiers
                } else {
                    switch groupIdentifier {
                    case .trackingTaskGroup:
                        return RSDIdentifier.trackingTasks
                    case .measuringTaskGroup:
                        return RSDIdentifier.measuringTasks
                    default:
                        assertionFailure("The list above of task groups to build does not match this one.")
                        return []
                    }
                }
            }()
            
            // Check that there is a mapped task info in the bridge configuration.
            activityIdentifiers.forEach { (activityId) in
                // Special-case the study burst completed schedule (it's never shown as a task).
                guard activityId != .studyBurstCompletedTask else { return }
                
                // If the installed info has an image then it's loaded.
                let installedInfo = configuration.activityInfo(for: activityId.stringValue)
                if installedInfo?.imageVendor != nil { return }
                
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
        }
    }
    
}
