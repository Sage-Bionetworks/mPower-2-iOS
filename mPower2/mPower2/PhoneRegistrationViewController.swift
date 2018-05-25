//
//  PhoneRegistrationViewController.swift
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
import Research
import ResearchUI
import BridgeSDK

class PhoneRegistrationViewController: RSDTableStepViewController {

    func signUpAndRequestSMSLink(completion: @escaping SBBNetworkManagerCompletionBlock) {
        guard let taskController = self.taskController as? SignInTaskViewController,
            let phoneNumber = taskController.phoneNumber,
            let regionCode = taskController.regionCode,
            !phoneNumber.isEmpty,
            !regionCode.isEmpty else {
                return
        }
        let signUp: SBBSignUp = SBBSignUp()
        signUp.checkForConsent = true
        signUp.phone = SBBPhone()
        signUp.phone!.number = phoneNumber
        signUp.phone!.regionCode = regionCode
        
        BridgeSDK.authManager.signUpStudyParticipant(signUp, completion: { (task, result, error) in
            guard error == nil else {
                completion(task, result, error)
                return
            }
            
            // we're signed up so request a sign-in link via SMS
            BridgeSDK.authManager.textSignInToken(to: phoneNumber, regionCode: regionCode, completion: { (task, result, error) in
                completion(task, result, error)
            })
        })
    }

    
    override func goForward() {
        guard validateAndSave()
            else {
                return
        }

        self.signUpAndRequestSMSLink { (task, result, error) in
            if error == nil {
                DispatchQueue.main.async {
                    super.goForward()
                }
            } else {
                // TODO emm 2018-04-25 handle error from Bridge
                // 400 is the response for an invalid phone number
                debugPrint("Error attempting to sign up and request SMS link:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
            }
        }
    }
}
