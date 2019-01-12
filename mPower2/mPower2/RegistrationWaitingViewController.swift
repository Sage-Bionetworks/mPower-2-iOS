//
//  RegistrationWaitingViewController.swift
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

class RegistrationWaitingViewController: RSDStepViewController {
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var enterCodeTextField: UITextField!
    @IBOutlet weak var submitButton: RSDRoundedButton!
    @IBOutlet weak var resendLinkButton: RSDUnderlinedButton!
    
    private static let kResendLinkDelay = 15.0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController {
            self.phoneLabel.text = taskController.phoneNumber
        }
    }
    
    private func showResendLinkAfterDelay() {
        
    }
    
    @IBAction func didTapChangeMobileButton(_ sender: Any) {
        guard let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController else { return }
        
        let alertController = UIAlertController(title: "Change phone number", message: "Enter a new phone number.", preferredStyle: .alert)

        let saveAction = UIAlertAction(title: Localization.localizedString("SUMBIT_BUTTON"), style: .default, handler: {
            alert -> Void in

            let textField = alertController.textFields![0] as UITextField
            let newNumber = textField.text
            
            // do nothing if they entered the same number
            guard newNumber != self.phoneLabel.text else { return }
            
            self.phoneLabel.text = newNumber
            var phoneResult = taskController.resultForPhoneNumber()
            phoneResult!.value = newNumber
            taskController.taskViewModel.taskResult.appendStepHistory(with: phoneResult!)
            
            taskController.showLoadingView()
            taskController.signUpAndRequestSMSLink { (task, result, error) in
                taskController.hideLoadingIfNeeded()
                
                guard let err = error as NSError?
                    else {
                        return
                }
                
                // 400 is the response for an invalid phone number
                if err.code == 400 {
                    self.presentAlertWithOk(title: "Wrong Number", message: "The phone number you entered is not valid. Please enter a valid U.S. phone number.", actionHandler: { (_) in
                        self.didTapChangeMobileButton(self)
                    })
                } else {
                    self.presentAlertWithOk(title: "Error", message: "The server returned an error: \(err)", actionHandler: { (_) in
                        self.didTapChangeMobileButton(self)
                    })
                }
                debugPrint("Error attempting to sign up and request SMS link:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
            }
        })

        let cancelAction = UIAlertAction(title: Localization.buttonCancel(), style: .default, handler: nil)

        alertController.addTextField { (textField : UITextField!) -> Void in

            textField.text = self.phoneLabel.text
            textField.keyboardType = .phonePad
            textField.placeholder = "Phone number"
            textField.addTarget(self, action: #selector(self.alertValidatePhoneText), for: .editingChanged)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        alertController.actions[1].isEnabled = false

        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc fileprivate func alertValidatePhoneText(_ sender: Any) {
        let textField = sender as! UITextField
        let newNumber = textField.text ?? ""
        
        // find the alert controller in the responder chain
        var responder: UIResponder = sender as! UIResponder
        while !(responder is UIAlertController) { responder = responder.next! }
        let alertController = responder as! UIAlertController
        
        // only enable the save action if it's a 10-digit number and not the same as the previous phone number
        let match = newNumber.range(of:"^\\d{10}$", options:.regularExpression)
        alertController.actions[1].isEnabled = (match != nil) && (newNumber != self.phoneLabel.text)
    }
    
    @IBAction func didTapResendLinkButton(_ sender: UIButton) {
        guard let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController else { return }
        
        self.resendLinkButton.isHidden = true
        taskController.showLoadingView()
        taskController.signUpAndRequestSMSLink { (task, result, error) in
            taskController.hideLoadingIfNeeded()
            
            guard let err = error as NSError?
                else {
                    return
            }
            
            // 400 is the response for an invalid phone number
            if err.code == 400 {
                self.presentAlertWithOk(title: "Wrong Number", message: "The phone number you entered is not valid. Please enter a valid U.S. phone number.", actionHandler: { (_) in
                    self.didTapChangeMobileButton(self)
                })
            } else {
                self.presentAlertWithOk(title: "Error", message: "The server returned an error: \(err)", actionHandler: { (_) in
                    self.didTapChangeMobileButton(self)
                })
            }
            debugPrint("Error attempting to re-sign up and re-request SMS link:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
        }
    }
    
    @IBAction func didTapSubmitButton(_ sender: Any) {
        guard let signInDelegate = (UIApplication.shared.delegate as? AppDelegate)?.smsSignInDelegate,
                let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController,
                let token = self.enterCodeTextField.text
            else { return }
        
        taskController.showLoadingView()
        signInDelegate.signIn(token: token)
    }
}
