//
//  ExternalIDRegistrationViewController.swift
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

import UIKit
import ResearchUI
import Research
import BridgeSDK
import BridgeApp

class ExternalIDRegistrationViewController: RSDTableStepViewController {

    func credentials() -> (externalId: String, firstName: String, preconsent: Bool)? {
        let taskResult = self.taskController.taskResult
        let externalIdResultIdentifier = "externalId"
        let firstNameResultIdentifier = "firstName"
        let preConsentResultIdentifier = "preConsent"
        guard let externalId = taskResult?.findAnswerResult(with: externalIdResultIdentifier)?.value as? String,
            let firstName = taskResult?.findAnswerResult(with: firstNameResultIdentifier)?.value as? String,
            let preconsent = taskResult?.findAnswerResult(with: preConsentResultIdentifier)?.value as? Bool
            else {
                return nil
        }

        return (externalId, firstName, preconsent)
    }

    
    func signUpAndSignIn(completion: @escaping SBBNetworkManagerCompletionBlock) {
        guard let credentials = self.credentials(), !credentials.externalId.isEmpty else { return }
        
        let signUp: SBBSignUp = SBBSignUp()
        signUp.checkForConsent = true
        signUp.externalId = credentials.externalId
        signUp.firstName = credentials.firstName
        signUp.password = credentials.externalId
        
        // TODO emm 2018-05-03 if we move this code to BridgeApp, we should prolly use an RSDCohortRule
        // or some such instead of hardcoding these dataGroup names.
        var dataGroups: Set<String> = ["test_user"]
        if credentials.preconsent {
            dataGroups.insert("test_no_consent")
        }
        /// Randomly assign one of the engagement data groups.
        if let engagementGroup = (SBABridgeConfiguration.shared as? MP2BridgeConfiguration)?.studyBurst.engagementDataGroups?.randomFirst() {
            dataGroups.insert(engagementGroup)
        }
        signUp.dataGroups = dataGroups
        
        BridgeSDK.authManager.signUpStudyParticipant(signUp, completion: { (task, result, error) in
            guard error == nil else {
                completion(task, result, error)
                return
            }
            
            // we're signed up so sign in
            BridgeSDK.authManager.signIn(withExternalId: signUp.externalId!, password: signUp.password!, completion: { (task, result, error) in
                completion(task, result, error)
            })
        })
    }
    
    override func goForward() {
        guard validateAndSave()
            else {
                return
        }
        
        self.signUpAndSignIn { (task, result, error) in
            if error == nil || (error! as NSError).code == SBBErrorCode.serverPreconditionNotMet.rawValue {
                DispatchQueue.main.async {
                    super.goForward()
                }
            } else {
                // TODO emm 2018-04-25 handle error from Bridge
                // 400 is the response for an invalid external ID
                debugPrint("Error attempting to sign up and sign in:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
            }
        }
    }

}
