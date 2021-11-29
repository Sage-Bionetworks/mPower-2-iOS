//
//  MobileToolboxConfig.swift
//  mPower2
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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
import MobileToolboxWrapper
import ResearchV2
import UIKit

class MobileToolboxConfig {
    static let shared: MobileToolboxConfig = .init()
    private init() {}
    
    private var mtbIdentifiers: [MTBIdentifier] = [
        .numberMatch,
        .mfs,
        .dccs]
    
    var excludeDataGroups: [String] = [
        TaskGroupScheduleManager.SHOW_HEART_SNAPSHOT_DATA_GROUP
    ]
}

extension MTBIdentifier : ResearchV2.RSDTaskInfo {
    
    public var identifier: String {
        self.rawValue
    }
    
    public var title: String? {
        switch self {
        case .numberMatch:
            return NSLocalizedString("Number-Symbol Match", comment: "\(self.rawValue)")
        case .mfs:
            return NSLocalizedString("Sequences", comment: "\(self.rawValue)")
        case .dccs:
            return NSLocalizedString("Shape-Color Sorting", comment: "\(self.rawValue)")
        case .fnamea:
            return NSLocalizedString("Faces & Names A", comment: "\(self.rawValue)")
        case .fnameb:
            return NSLocalizedString("Faces & Names B", comment: "\(self.rawValue)")
        case .flanker:
            return NSLocalizedString("Arrow Matching", comment: "\(self.rawValue)")
        case .psm:
            return NSLocalizedString("Arranging Pictures", comment: "\(self.rawValue)")
        case .spelling:
            return NSLocalizedString("Spelling", comment: "\(self.rawValue)")
        case .vocabulary:
            return NSLocalizedString("Word Meaning", comment: "\(self.rawValue)")
        @unknown default:
            return self.rawValue
        }
    }
    
    public var estimatedMinutes: Int {
        5
    }
    
    public func copy(with identifier: String) -> MTBIdentifier {
        self
    }
    
    public var imageVendor: ResearchV2.RSDImageVendor? {
        UIImage(named: "CognitionTaskIcon")
    }
    
    public var subtitle: String? {
        nil
    }
    
    public var detail: String? {
        nil
    }
    
    public var schemaInfo: ResearchV2.RSDSchemaInfo? {
        nil
    }
    
    public var resourceTransformer: ResearchV2.RSDTaskTransformer? {
        nil
    }
}
