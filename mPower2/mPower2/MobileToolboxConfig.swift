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
import BridgeSDK
import BridgeApp

fileprivate let kLastMTBIdentifierKey = "LastMTBIdentifier"
fileprivate let kLastMTBFinishedDateKey = "LastMTBFinishedDate"

class MobileToolboxConfig {
    static let shared: MobileToolboxConfig = .init()
    private init() {}
    
    var mtbIdentifiers: [MTBIdentifier] = [
        .numberMatch,
        .mfs,
        .dccs]
    
    func nextTask() -> MTBIdentifier? {
        guard let lastFinished = lastFinishedDate(),
              lastFinished.addingNumberOfDays(20) > Date(),
              let lastIdentifier = lastFinishedIdentifier()
        else {
            return mtbIdentifiers.first
        }
        if lastFinished.isToday {
            return nil
        }
        return mtbIdentifiers.rsd_next(after: { lastIdentifier == $0 })
    }
    
    func taskFinishedToday() -> Bool {
        lastFinishedDate()?.isToday ?? false
    }

    func finishedAssessment(_ mtbIdentifier: MTBIdentifier, reason: MobileToolboxWrapper.FinishedState) {
        switch reason {
        case .completed, .skipped:
            saveLastFininshedDate(for: mtbIdentifier)
        default:
            break
        }
    }
    
    /// A serial queue used to manage data crunching.
    let offMainQueue = DispatchQueue(label: "org.sagebionetworks.mPower.MobileToolboxConfig")
    
    func saveAssessment(_ result: MTBAssessmentResult) {
        let identifier = result.schemaIdentifier ?? result.identifier
        let archive = SBBDataArchive(reference: identifier, jsonValidationMapping: nil)
        if let schemaRevision = SBABridgeConfiguration.shared.schemaInfo(for: identifier)?.schemaVersion {
            archive.setArchiveInfoObject(NSNumber(value: schemaRevision), forKey: "schemaRevision")
        }
        archive.insertData(intoArchive: result.json, filename: result.filename, createdOn: result.timestamp)
        if result.filename == "taskData" {
            archive.insertData(intoArchive: result.json, filename: "\(result.filename).json", createdOn: result.timestamp)
        }
        offMainQueue.async {
            archive.encryptAndUploadArchive()
        }
    }
    
    func lastFinishedDate() -> Date? {
        UserDefaults.standard.object(forKey: kLastMTBFinishedDateKey) as? Date
    }
    
    func lastFinishedIdentifier() -> MTBIdentifier? {
        UserDefaults.standard.string(forKey: kLastMTBIdentifierKey).flatMap { .init(rawValue: $0) }
    }
    
    func saveLastFininshedDate(for mtbIdentifier: MTBIdentifier) {
        UserDefaults.standard.set(mtbIdentifier.rawValue, forKey: kLastMTBIdentifierKey)
        UserDefaults.standard.set(Date(), forKey: kLastMTBFinishedDateKey)
    }
}

extension MobileToolboxWrapper.FinishedState {
    var rsdV2Reason: ResearchV2.RSDTaskFinishReason {
        switch self {
        case .completed, .skipped:
            return .completed
        case .saved:
            return .saved
        default:
            return .discarded
        }
    }
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
