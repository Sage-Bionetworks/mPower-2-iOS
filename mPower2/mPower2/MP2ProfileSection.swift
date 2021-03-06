//
//  MP2ProfileSection.swift
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

import BridgeApp

extension SBAProfileTableItemType {
    /// Creates a `StudyParticipationProfileTableItem`.
    public static let studyParticipation: SBAProfileTableItemType = "studyParticipation"
    
    /// Creates a `PermissionsProfileTableItem`.
    public static let permissions: SBAProfileTableItemType = "permissions"
    
    /// Creates a `SettingsProfileTableItem`.
    public static let settings: SBAProfileTableItemType = "settings"
    
    /// Creates a `MailToProfileTableItem`.
    public static let mailTo: SBAProfileTableItemType = "mailTo"
}

class MP2ProfileSection: SBAProfileSectionObject {

    override open func decodeItem(from decoder:Decoder, with type:SBAProfileTableItemType) throws -> SBAProfileTableItem? {
        switch type {
        case .studyParticipation:
            return try StudyParticipationProfileTableItem(from: decoder)
        case .permissions:
            return try PermissionsProfileTableItem(from: decoder)
        case .settings:
            return try SettingsProfileTableItem(from: decoder)
        case .mailTo:
            return try MailToProfileTableItem(from: decoder)
        default:
            return try super.decodeItem(from: decoder, with: type)
        }
    }

}
