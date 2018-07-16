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

// https://stackoverflow.com/a/27140764
extension UIResponder {
    private weak static var _currentFirstResponder: UIResponder? = nil
    
    public static var current: UIResponder? {
        UIResponder._currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(sender:)), to: nil, from: nil, for: nil)
        return UIResponder._currentFirstResponder
    }
    
    @objc internal func findFirstResponder(sender: AnyObject) {
        UIResponder._currentFirstResponder = self
    }
}

class PhoneRegistrationViewController: RSDTableStepViewController {

    override func goForward() {
        guard validateAndSave()
            else {
                return
        }
        
        guard let taskController = self.taskController as? SignInTaskViewController,
                let phoneNumber = taskController.phoneNumber
            else {
                return
        }

        // start with the "original" next step identifier from json (if saved)
        let stepObject = self.step as! RSDUIStepObject
        stepObject.nextStepIdentifier = taskController.phoneSavedNextStepIdentifier ?? stepObject.nextStepIdentifier
        
        // save the current first responder so we can restore it after any alerts go away
        let thingBeingEdited = UIResponder.current
        func restoreResponder() {
            thingBeingEdited?.becomeFirstResponder()
        }
        tableView?.endEditing(false)

        if let _ = phoneNumber.range(of: "\\d\\d\\d55501\\d\\d$", options: .regularExpression) {
            // they said the secret word so ask if they want to be a tester
            self.presentAlertWithYesNo(title: "Tester", message: "The phone number you entered is fictional. Do you want to sign in with a test ID?") { (tester) in
                if tester {
                    // boop them over to the externalID sign-in step
                    taskController.phoneSavedNextStepIdentifier = stepObject.nextStepIdentifier
                    stepObject.nextStepIdentifier = "enterExternalId"
                    super.goForward()
                } else {
                    restoreResponder()
                }
            }
            return
        }

        taskController.showLoadingView()
        taskController.signUpAndRequestSMSLink { (task, result, error) in
            taskController.hideLoadingIfNeeded()
            
            guard let err = error as NSError?
                else {
                    super.goForward()
                    return
            }
            
            // 400 is the response for an invalid phone number
            if err.code == 400 {
                self.presentAlertWithOk(title: "Wrong Number", message: "The phone number you entered is not valid. Please enter a valid U.S. phone number.", actionHandler: { (_) in
                    restoreResponder()
                })
            } else {
                self.presentAlertWithOk(title: "Error", message: "The server returned an error: \(err)", actionHandler: { (_) in
                    restoreResponder()
                })
            }
            debugPrint("Error attempting to sign up and request SMS link:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
        }
    }
}
