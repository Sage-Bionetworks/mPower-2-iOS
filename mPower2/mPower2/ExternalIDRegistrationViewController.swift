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

class ExternalIDRegistrationViewController: RSDTableStepViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func credentials() -> (externalID: String?, preconsent: Bool?) {
        let resultStepIdentifier = "enterExternalId"
        let taskPath = self.taskController.taskPath!
        let sResult = taskPath.result.stepHistory.first { $0.identifier == resultStepIdentifier}
        guard let stepResult = sResult as? RSDCollectionResult
            else {
                return (nil, nil)
        }
        
        let externalIdResultIdentifier = "externalId"
        let resultForExternalId = stepResult.inputResults.first { $0.identifier == externalIdResultIdentifier }
        guard let eResult = resultForExternalId as? RSDAnswerResult,
            let externalId = eResult.value as? String
            else {
                return (nil, nil)
        }
        let preConsentResultIdentifier = "preConsent"
        let resultForPreConsent = stepResult.inputResults.first { $0.identifier == preConsentResultIdentifier }
        guard let pResult = resultForPreConsent as? RSDAnswerResult,
            let preconsent = pResult.value as? Bool
            else {
                return (nil, nil)
        }

        return (externalId, preconsent)
    }

    
    func signUpAndSignIn(completion: @escaping SBBNetworkManagerCompletionBlock) {
        let (ex, pc) = self.credentials()
        guard let externalId = ex, let preconsent = pc, externalId.isEmpty == false else {
            return
        }
        
        let signUp: SBBSignUp = SBBSignUp()
        signUp.checkForConsent = true
        signUp.externalId = externalId
        signUp.password = externalId
        if preconsent {
            signUp.dataGroups = ["test_user", "test_no_consent"]
        } else {
            signUp.dataGroups = ["test_user"]
        }
        
        BridgeSDK.authManager.signUpStudyParticipant(signUp, completion: { (task, result, error) in
            guard error == nil else {
                completion(task, result, error)
                return
            }
            
            // we're signed up so sign in
            BridgeSDK.authManager.signIn(withExternalId: externalId, password: externalId, completion: { (task, result, error) in
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
