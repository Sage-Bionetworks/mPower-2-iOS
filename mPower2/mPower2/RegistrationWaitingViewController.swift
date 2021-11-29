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
import ResearchV2UI
import ResearchV2
import BridgeSDK

class RegistrationWaitingViewController: RSDStepViewController, UITextFieldDelegate {
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var enterCodeTextField: UITextField!
    @IBOutlet weak var submitButton: RSDRoundedButton!
    @IBOutlet weak var resendLinkButton: RSDUnderlinedButton!
    
    private let kResendLinkDelay = 15.0
    
    private var resendLinkTimer: Timer?
    
    private var keyboardWillShowObserver: Any?
    private var keyboardWillHideObserver: Any?
    private var textDidChangeObserver: Any?
    private var savedViewYPosition: CGFloat = 0.0
    
    private let kKeyboardPadding: CGFloat = 5.0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController {
            self.phoneLabel.text = taskController.phoneNumber
        }
        
        self.showResendLinkAfterDelay()
        
        // Add observers for keyboard show/hide notifications and text changes.
        let center = NotificationCenter.default
        let mainQ = OperationQueue.main
        
        self.keyboardWillShowObserver = center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: mainQ, using: { (notification) in
            guard let keyboardRect = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    let screenCoordinates = self.view.window?.screen.fixedCoordinateSpace
                else { return }
            
            self.savedViewYPosition = self.view.frame.origin.y
            let submitView = self.submitButton!
            let submitFrame = submitView.convert(submitView.bounds, to: screenCoordinates) // keyboardRect is in screen coordinates.
            let submitFrameBottom = submitFrame.origin.y + submitFrame.size.height
            let yOffset = keyboardRect.origin.y - submitFrameBottom - self.kKeyboardPadding
            
            // Don't scroll if the bottom of the code entry field is already above the keyboard.
            if yOffset < 0 {
                var newFrame = self.view.frame
                newFrame.origin.y += yOffset
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = newFrame
                })
            }
        })
        
        self.keyboardWillHideObserver = center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: mainQ, using: { (notification) in
            var oldFrame = self.view.frame
            
            // If we scrolled it when the keyboard slid up, scroll it back now.
            if oldFrame.origin.y != self.savedViewYPosition {
                oldFrame.origin.y = self.savedViewYPosition
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = oldFrame
                })
            }
        })
        
        self.textDidChangeObserver = center.addObserver(forName: UITextField.textDidChangeNotification, object: nil, queue: mainQ, using: { (notification) in
            // Update the Submit button's enabled state.
            let textField = self.enterCodeTextField!
            let newNumber = textField.text ?? ""
            
            // Only enable the submit button if it's a 6-digit number, possibly copypasted with a hyphen in the middle.
            let match = newNumber.range(of:"^\\d{3}-?\\d{3}$", options:.regularExpression)
            self.submitButton.isEnabled = (match != nil)

        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.resendLinkTimer?.invalidate()
        self.resendLinkTimer = nil
        
        // Remove keyboard show/hide notification listeners.
        let center = NotificationCenter.default
        if let showObserver = self.keyboardWillShowObserver {
            center.removeObserver(showObserver)
        }
        if let hideObserver = self.keyboardWillHideObserver {
            center.removeObserver(hideObserver)
        }
        
        super.viewWillDisappear(animated)
    }
    
    private func showResendLinkAfterDelay() {
        self.resendLinkTimer = Timer.scheduledTimer(withTimeInterval: self.kResendLinkDelay, repeats: false) {_ in
            self.resendLinkButton.isHidden = false
        }
    }
    
    @IBAction func didTapChangeMobileButton(_ sender: Any) {
        guard let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController else { return }
        
        let alertController = UIAlertController(title: "Change phone number", message: "Enter a new phone number.", preferredStyle: .alert)

        let saveAction = UIAlertAction(title: Localization.localizedString("SUMBIT_BUTTON"), style: .default, handler: {
            alert -> Void in

            let textField = alertController.textFields![0] as UITextField
            let newNumber = textField.text
            
            // Do nothing if they entered the same number.
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
                
                // 400 is the response for an invalid phone number.
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
        
        // Find the alert controller in the responder chain.
        var responder: UIResponder = sender as! UIResponder
        while !(responder is UIAlertController) { responder = responder.next! }
        let alertController = responder as! UIAlertController
        
        // Only enable the save action if it's a 10-digit number and not the same as the previous phone number.
        let match = newNumber.range(of:"^\\d{10}$", options:.regularExpression)
        alertController.actions[1].isEnabled = (match != nil) && (newNumber != self.phoneLabel.text)
    }
    
    @IBAction func didTapResendLinkButton(_ sender: UIButton) {
        guard let taskController = self.stepViewModel.rootPathComponent.taskController as? SignInTaskViewController else { return }
        
        self.resendLinkButton.isHidden = true
        taskController.showLoadingView()
        taskController.signUpAndRequestSMSLink { (task, result, error) in
            taskController.hideLoadingIfNeeded()
            
            // Restart the resend link timer in case it still doesn't arrive soon-ish.
            self.showResendLinkAfterDelay()
            
            guard let err = error as NSError?
                else {
                    return
            }
            
            // 400 is the response for an invalid phone number.
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
    
    // MARK: UITextField delegate
    
    /// Resign first responder on "Enter" key tapped.
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.canResignFirstResponder {
            textField.resignFirstResponder()
        }
        return false
    }
}
