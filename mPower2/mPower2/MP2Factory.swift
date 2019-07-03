//
//  MP2Factory.swift
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

extension RSDStepType {
    /// Defaults to a `ReminderStep`.
    public static let reminder: RSDStepType = "reminder"
    /// Defaults to a `TrackedItemsIntroductionStepObject`
    public static let trackedItemsIntroduction: RSDStepType = "trackedItemsIntroduction"
    /// Defaults to a `PassiveDataPermissionStepObject`.
    public static let passiveDataPermission: RSDStepType = "passiveDataPermission"
}

extension SBAProfileDataSourceType {
    /// Defaults to a `MP2ProfileDataSource`.
    public static let mp2ProfileDataSource: SBAProfileDataSourceType = "mp2ProfileDataSource"
}

class MP2Factory : SBAFactory {
    
    override func decodeStep(from decoder:Decoder, with type:RSDStepType) throws -> RSDStep? {
        
        switch (type) {
        case .reminder:
            return try ReminderStep(from: decoder)
        case .trackedItemsIntroduction:
            return try TrackedItemsIntroductionStepObject(from: decoder)
        case .passiveDataPermission:
            return try PassiveDataPermissionStepObject(from: decoder)
        default:
            return try super.decodeStep(from: decoder, with: type)
        }
    }
    
    override func decodeProfileDataSource(from decoder: Decoder) throws -> SBAProfileDataSource {
        let type = try decoder.factory.typeName(from: decoder) ?? SBAProfileDataSourceType.mp2ProfileDataSource.rawValue
        let dsType = SBAProfileDataSourceType(rawValue: type)

        switch dsType {
        case .mp2ProfileDataSource:
            return try MP2ProfileDataSource(from: decoder)
        default:
            return try super.decodeProfileDataSource(from: decoder)
        }
    }

}
