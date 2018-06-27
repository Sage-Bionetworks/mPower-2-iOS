//
//  ParticipantManager.swift
//  mPower2TestApp
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
@testable import BridgeSDK

public class ParticipantManager : NSObject, SBBParticipantManagerProtocol {
    
    var participant: SBBStudyParticipant
    
    public init(studySetup: StudySetup) {
        self.participant = studySetup.createParticipant()
        super.init()
    }
    
    public let offMainQueue = DispatchQueue(label: "org.sagebionetworks.BridgeApp.TestParticipantManager")
    
    public func getParticipantRecord(completion: SBBParticipantManagerGetRecordCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func updateParticipantRecord(withRecord participant: Any?, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            if let newParticipant = participant as? SBBStudyParticipant {
                self.participant = newParticipant
                completion?(self.participant, nil)
            }
            else {
                let err = NSError(domain: "TestApp", code: 1, userInfo: nil)
                completion?(nil, err)
            }
        }
        return URLSessionTask()
    }
    
    public func setExternalIdentifier(_ externalID: String?, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            self.participant.externalId = externalID
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func setSharingScope(_ scope: SBBParticipantDataSharingScope, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            self.participant.sharingScope = scope.stringValue
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func getDataGroups(completion: @escaping SBBParticipantManagerGetGroupsCompletionBlock) -> URLSessionTask? {
        offMainQueue.async {
            completion(self.participant.dataGroups, nil)
        }
        return URLSessionTask()
    }
    
    public func updateDataGroups(withGroups dataGroups: Set<String>, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            self.participant.dataGroups = dataGroups
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func add(toDataGroups dataGroups: Set<String>, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            let previousGroups = self.participant.dataGroups ?? Set<String>()
            self.participant.dataGroups = previousGroups.union(dataGroups)
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func remove(fromDataGroups dataGroups: Set<String>, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            let previousGroups = self.participant.dataGroups ?? Set<String>()
            self.participant.dataGroups = previousGroups.subtracting(dataGroups)
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
}

extension SBBParticipantDataSharingScope {
    var stringValue: String {
        switch self {
        case .all:
            return "all"
        case .none:
            return "none"
        case .study:
            return "study"
        }
    }
}
