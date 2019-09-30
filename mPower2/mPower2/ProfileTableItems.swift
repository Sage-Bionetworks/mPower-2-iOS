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
import DataTracking

extension SBAProfileOnSelectedAction {
    public static let permissionsProfileAction: SBAProfileOnSelectedAction = "permissionsProfileAction"
    public static let settingsProfileAction: SBAProfileOnSelectedAction = "settingsProfileAction"
/* TODO: emm 2019-06-12 deal with this for v2.1
    public static let scheduleProfileAction: SBAProfileOnSelectedAction = "scheduleProfileAction"
    public static let downloadDataAction: SBAProfileOnSelectedAction = "downloadDataAction"
 */
}

/// Define the available profile settings that mPower 2 knows how to handle via the SettingsProfileTableItem.
public struct MP2ProfileSetting : RawRepresentable, Codable {
    public typealias RawValue = String
    
    public private(set) var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let medicationReminders: MP2ProfileSetting = "medicationReminders"
    public static let studyBurstTime: MP2ProfileSetting = "studyBurstTime"
}

extension MP2ProfileSetting : Equatable {
    public static func ==(lhs: MP2ProfileSetting, rhs: MP2ProfileSetting) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    public static func ==(lhs: String, rhs: MP2ProfileSetting) -> Bool {
        return lhs == rhs.rawValue
    }
    public static func ==(lhs: MP2ProfileSetting, rhs: String) -> Bool {
        return lhs.rawValue == rhs
    }
}

extension MP2ProfileSetting : Hashable {
    public var hashValue : Int {
        return self.rawValue.hashValue
    }
}

extension MP2ProfileSetting : ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}


struct PermissionsProfileTableItem: SBAProfileTableItem, Decodable {
    /// The title text to show for the item.
    var title: String?
    
    /// The type of permissions to display/manage.
    var permissionType: RSDStandardPermissionType
    
    /// For the detail text, show their current status for the specified permission type.
    var detail: String? {
        get {
            let status = RSDAuthorizationHandler.authorizationStatus(for: permissionType.identifier)
            let detailKey = (status == .authorized) ? "PERMISSIONS_STATE_ON" : "PERMISSIONS_STATE_OFF"
            return Localization.localizedString(detailKey)
        }
    }
    
    /// The PermissionsProfileTableItem is 'editable' in the sense that you can tap it to change it, but other
    /// than requesting a permission that hasn't yet been granted or denied, the participant will be directed
    /// to the Settings app to change it.
    var isEditable: Bool? {
        return true
    }
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    var inCohorts: Set<String>?
    
    /// A set of cohorts (data groups) the participant must **not** be in, in order to show this item in its containing profile section.
    var notInCohorts: Set<String>?
    
    /// The action when this item is selected is to request the permission if not already granted or denied, or
    /// to direct the participant to the Settings app to change the permission if it's been previously set.
    var onSelected: SBAProfileOnSelectedAction? {
        return .permissionsProfileAction
    }
}

/// The SettingsProfileTableItem is sort of a catch-all for "other" one-off sorts of items, like the various
/// reminder settings, that for now at least don't really make sense to each have their own profile table item
/// type and onSelected action.
struct SettingsProfileTableItem: SBAProfileTableItem, Decodable {
    /// The title text to show for the item.
    var title: String?
    
    /// The setting to display/manage via this item.
    var setting: MP2ProfileSetting
    
    /// For the detail text, show their current setting state.
    var detail: String? {
        switch self.setting {
        case .medicationReminders:
            // Return the current setting for how far in advance to send medication reminders.
            guard let reminders = SBAMedicationReminderManager.shared.getMedicationResult()?.reminders,
                    reminders.count > 0
                else {
                    return ""
            }
            let minutes = reminders[0]
            let dateComponents = DateComponents(minute: minutes)
            guard let minutesString = DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .full)
                else {
                    return ""
            }

            return Localization.localizedStringWithFormatKey("MEDICATION_REMINDER_MINUTES_BEFORE", minutesString)
            
        case .studyBurstTime:
            // Return the current setting for study burst reminder time.
            guard let dateComponents = StudyBurstScheduleManager.shared.getReminderTime()
                else {
                    return ""
            }
            return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .positional)
            
        default:
            debugPrint("Don't know how to show current setting for unknown setting '\(self.setting.rawValue)'; returning empty string")
            return ""
       }
    }
    
    /// The current set of SettingsProfileTableItem settings are all editable.
    var isEditable: Bool? {
        return true
    }
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    var inCohorts: Set<String>?
    
    /// A set of cohorts (data groups) the participant must **not** be in, in order to show this item in its containing profile section.
    var notInCohorts: Set<String>?
    
    /// The action when this item is selected will depend on the specific setting. The table view controller will need
    /// to examine the item's `setting` field and proceed accordingly.
    var onSelected: SBAProfileOnSelectedAction? {
        return .settingsProfileAction
    }
    
    
}

/* TODO: emm 2018-08-21 deal with this for v2.1
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

struct StudyParticipationProfileTableItem: SBAProfileTableItem, Decodable {
    
    /// The title text to show for the item.
    var title: String?
    
    /// For the detail text, show their current participation status.
    var detail: String? {
        get {
            let enrolled = SBAParticipantManager.shared.isConsented
            let key = enrolled ? "PARTICIPATION_ENROLLED_%@" : "PARTICIPATION_REJOIN_%@"
            let format = Localization.localizedString(key)
            return String.localizedStringWithFormat(format, Localization.localizedAppName)
        }
    }
    
    /// The StudyParticipationProfileTableItem is not editable.
    var isEditable: Bool? {
        return false
    }
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    var inCohorts: Set<String>?
    
    /// A set of cohorts (data groups) the participant must **not** be in, in order to show this item in its containing profile section.
    var notInCohorts: Set<String>?
    
    /// The action when this item is selected is to show the participation/withdrawal screen.
    var onSelected: SBAProfileOnSelectedAction? {
        return .showWithdrawal
    }
}
