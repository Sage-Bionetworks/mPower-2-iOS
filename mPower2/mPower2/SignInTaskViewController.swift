//
//  SignInTaskViewController.swift
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

import Research
import ResearchUI
import BridgeSDK

protocol SignInDelegate : class {
    func signIn(token: String)
}

class SignInTaskViewController: RSDTaskViewController, SignInDelegate {
    var phoneNumber: String? {
        let taskResult = self.taskResult
        let phoneResultIdentifier = "enterPhoneNumber"
        guard let phoneNumber = taskResult?.findAnswerResult(with: phoneResultIdentifier)?.value as? String
            else {
                return nil
        }
        
        return phoneNumber
    }
    
    var regionCode: String? = "US" // TODO: emm 2018-04-25 Handle non-US phone numbers for international studies

    init() {
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: "SignIn")
            let task = try RSDFactory.shared.decodeTask(with: resourceTransformer)
            let taskPath = RSDTaskPath(task: task)
            super.init(taskPath: taskPath)
        } catch let err {
            fatalError("Failed to decode the SignIn task. \(err)")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        (UIApplication.shared.delegate as? AppDelegate)?.smsSignInDelegate = self
    }

    func signIn(token: String) {
        guard let phoneNumber = self.phoneNumber,
            !phoneNumber.isEmpty,
            let regionCode = self.regionCode,
            !regionCode.isEmpty else {
                debugPrint("Unable to sign in: phone number or region code is missing or empty")
                return
        }
        
        BridgeSDK.authManager.signIn(withPhoneNumber:phoneNumber, regionCode:regionCode, token:token, completion: { (task, result, error) in
            if error == nil || (error! as NSError).code == SBBErrorCode.serverPreconditionNotMet.rawValue {
                DispatchQueue.main.async {
                    // TODO emm 2018-05-04 handle navigation for consented vs not consented
                    self.currentStepController?.goForward()
                }
            } else {
                // TODO emm 2018-05-04 handle error from Bridge
                debugPrint("Error attempting to sign in with SMS link:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
            }
        })
    }
}
