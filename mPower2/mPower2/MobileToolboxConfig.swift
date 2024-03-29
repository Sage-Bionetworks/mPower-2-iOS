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
import SwiftUI

let kCognitionTaskTitle = "title"

fileprivate let kLastMTBIdentifierKey = "LastMTBIdentifier"
fileprivate let kLastMTBFinishedDateKey = "LastMTBFinishedDate"

fileprivate let kMTBTaskGroup3 = "show_3_cognitive"
fileprivate let kMTBTaskGroup8 = "show_8_cognitive"

class MobileToolboxConfig : SBAReportManager {
    static let shared: MobileToolboxConfig = .init()
        
    var mtbIdentifiers: [MTBIdentifier] {
        guard let dataGroups = SBAParticipantManager.shared.studyParticipant?.dataGroups
        else {
            return []
        }
        if dataGroups.contains(kMTBTaskGroup3) {
            return [.numberMatch,
                    .mfs,
                    .dccs]
        }
        else if dataGroups.contains(kMTBTaskGroup8) {
            return MTBIdentifier.allCases
        }
        else {
            return []
        }
    }
    
    func shouldShowTaskToday() -> Bool {
        // Exit early if we are not in a study burst.
        guard StudyBurstScheduleManager.shared.hasStudyBurst else { return false }
        let next = nextTaskInCurrentStudyBurst()
        return next.identifier != nil || (next.timestamp?.isToday == true)
    }
    
    func nextTask() -> MTBIdentifier? {
        // Exit early if we are not in a study burst.
        guard StudyBurstScheduleManager.shared.hasStudyBurst else { return nil }
        
        // Show whatever the next cognition task is (if there is one).
        return nextTaskInCurrentStudyBurst().identifier
    }
    
    /// Get the last task finished within this study burst.
    private func nextTaskInCurrentStudyBurst() -> (identifier: MTBIdentifier?, timestamp: Date?) {
        guard let lastFinished = lastFinishedDate(),
              lastFinished.addingNumberOfDays(20) > Date(),
              let lastIdentifier = lastFinishedIdentifier()
        else {
            return (mtbIdentifiers.first, nil)
        }
        return (mtbIdentifiers.next(lastIdentifier), lastFinished)
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
    
    func saveAssessment(_ result: MTBAssessmentResult) {
        // Send all data from Mobile Toolbox to the same Synapse table and let researchers
        // process it. For now, leave in the commented-out implementation that directs the
        // results to a different table based on the schema identifier. syoung 12/01/2021
        let schemaIdentifer = "MobileToolbox" //result.schemaIdentifier ?? result.identifier
        let schemaRevision = SBABridgeConfiguration.shared.schemaInfo(for: schemaIdentifer)?.schemaVersion
        let dataGroups = SBAParticipantManager.shared.studyParticipant?.dataGroups
        result.archiveAndUpload(schemaIdentifier: schemaIdentifer, schemaRevision: schemaRevision, dataGroups: dataGroups)
        
        // Add a report so that history can include this assessment.
        var json: [String : Any] = ["taskIdentifier" : result.identifier]
        json[SBATaskRunUUIDKey] = result.taskRunUUID?.uuidString
        json[kCognitionTaskTitle] = MTBIdentifier(rawValue: result.identifier)?.localizedTitle()
        self.saveReport(.init(reportKey: .cognitionTask, date: result.timestamp, clientData: json as SBBJSONValue))
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
    
    override func reportQueries() -> [SBAReportManager.ReportQuery] {
        let endDate = self.now()
        let startDate = endDate.addingNumberOfDays(-20)
        return [.init(reportKey: .cognitionTask, queryType: .mostRecent, dateRange: (startDate, endDate))]
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

extension Sequence where Element : Equatable {
    fileprivate func next(_ element: Element) -> Element? {
        rsd_next(after: { element == $0 })
    }
}

extension MTBIdentifier : ResearchV2.RSDTaskInfo {
    
    public var identifier: String {
        RSDIdentifier.cognitionTask.identifier
    }
    
    public var title: String? {
        NSLocalizedString("Cognition", comment: "Title for the cognition tasks")
    }
    
    public var estimatedMinutes: Int {
        5
    }
    
    public func copy(with identifier: String) -> MTBIdentifier {
        self
    }
    
    public var imageVendor: ResearchV2.RSDImageVendor? {
        UIImage(named: "\(identifier)TaskIcon")
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
