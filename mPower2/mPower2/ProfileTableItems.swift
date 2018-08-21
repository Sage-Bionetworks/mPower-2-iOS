//
//  ProfileTableItems.swift
//  mPower2
//
//  Copyright © 2017-2018 Sage Bionetworks. All rights reserved.
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

import BridgeApp

let scheduleProfileAction: SBAProfileOnSelectedAction = SBAProfileOnSelectedAction("scheduleProfileAction")
let settingsProfileAction: SBAProfileOnSelectedAction = SBAProfileOnSelectedAction("settingsProfileAction")

let changePasscodeAction: SBAProfileOnSelectedAction = SBAProfileOnSelectedAction("changePasscodeAction")
let downloadDataAction: SBAProfileOnSelectedAction = SBAProfileOnSelectedAction("downloadDataAction")

/* TODO: emm 2018-08-21 deal with this for v2.1
class SettingsProfileTableItem: SBAProfileTableItemBase {
    
    lazy var permissionsManager = {
        return SBAPermissionsManager.shared
    }()
    
    var permissionType: SBAPermissionObjectType!
    
    public required init(dictionaryRepresentation dictionary: [AnyHashable: Any]) {
        super.init(dictionaryRepresentation: dictionary)
        let identifier = dictionary["settingType"] as! String
        permissionType = permissionsManager.permissionsTypeFactory.permissionType(for: identifier)
        defaultOnSelectedAction = settingsProfileAction
    }
    
    override open var detail: String {
        get {
            let hasPermission = permissionsManager.isPermissionGranted(for: permissionType)
            var detailKey = hasPermission ? "JP_HAS_PERMISSION" : "JP_NO_PERMISSION"
            if permissionType.permissionType == SBAPermissionTypeIdentifier.location {
                let status = CLLocationManager.authorizationStatus()
                switch status {
                case .authorizedAlways:
                    detailKey = "JP_HAS_PERMISSION_ALWAYS"
                case .authorizedWhenInUse:
                    detailKey = "JP_HAS_PERMISSION_WHILE_USING"
                default:
                    break
                }
            }
            return Localization.localizedString(detailKey)
        }
    }
}

class ScheduleProfileTableItem: SBAProfileTableItemBase {
    
    public required init(dictionaryRepresentation dictionary: [AnyHashable: Any]) {
        super.init(dictionaryRepresentation: dictionary)
        let scheduleIdentifier = dictionary["scheduleIdentifier"] as! String
        let scheduleId = TaskIdentifier(rawValue: scheduleIdentifier)
        self.taskGroup = ScheduleSection.scheduleGroups.first(where: { $0.scheduleTaskIdentifier == scheduleId })!
        defaultOnSelectedAction = scheduleProfileAction
    }
    
    var taskGroup: TaskGroup!
    
    override open var detail: String {
        get {
            let schedule = MasterScheduledActivityManager.shared.schedule(for: taskGroup)
            return schedule?.localizedString ?? ""
        }
    }
}

class DownloadDataProfileTableItem: SBAProfileTableItemBase {
    public required init(dictionaryRepresentation dictionary: [AnyHashable: Any]) {
        super.init(dictionaryRepresentation: dictionary)
    }
}
 */

class StudyParticipationProfileTableItem: SBAProfileTableItemBase {
    /// Override to return .showWithdrawal as the default onSelected action.
    override open func defaultOnSelectedAction() -> SBAProfileOnSelectedAction {
        return .showWithdrawal
    }

    override open var detail: String {
        get {
            let appDelegate = AppDelegate.shared as! AppDelegate
            let enrolled = appDelegate.userSessionInfo?.consentedValue ?? false
            let key = enrolled ? "PARTICIPATION_ENROLLED_%@" : "PARTICIPATION_REJOIN_%@"
            let format = Localization.localizedString(key)
            return String.localizedStringWithFormat(format, Localization.localizedAppName)
        }
    }
}
