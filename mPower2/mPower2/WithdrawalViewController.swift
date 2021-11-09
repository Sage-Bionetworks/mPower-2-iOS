//
//  WithdrawalViewController.swift
//  mPower2
//
//  Copyright © 2017-2018 Sage Bionetworks. All rights reserved.
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

import BridgeAppUI

class WithdrawalViewController: UIViewController, RSDTaskViewControllerDelegate {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var backButton: UIButton!
    @IBOutlet var withdrawalButton: RSDRoundedButton!
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // This screen will be shown underneath the screen that actually withdraws from the study,
        // so check if we are returning to it after we have already withdrawn, or are not signed in
        if !BridgeSDK.authManager.isAuthenticated() {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func backButtonTapped(_ sender: Any!) {
        navigationController?.popViewController(animated: true)
    }
    
    func setupViews() {
        
        let designSystem = RSDDesignSystem()

        self.view.backgroundColor = designSystem.colorRules.backgroundPrimary.color
        
        // Setup title label
        titleLabel.textColor = UIColor.white
        let titleFormat = Localization.localizedString("WITHDRAWAL_TITLE_%@_%@")
        let studyParticipant = SBAParticipantManager.shared.studyParticipant
        let usersName = studyParticipant?.firstName ?? ""
        let startDate = studyParticipant?.createdOn ?? Date()
        let studyStartDateString = DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .none)
        self.titleLabel.text = String(format: titleFormat, usersName, studyStartDateString)

        // Setup title label
        subtitleLabel.textColor = UIColor.white
        subtitleLabel.text = Localization.localizedString("WITHDRAWAL_SUBTITLE")
        
        // Setup withdrawal button
        withdrawalButton.setTitle(Localization.localizedString("WITHDRAWAL_FROM_STUDY_BTN_TITLE"), for: .normal)
        withdrawalButton.setTitleColor(designSystem.colorRules.palette.errorRed.dark.color, for: .normal)
        withdrawalButton.backgroundColor = UIColor.white
        withdrawalButton.addTarget(self, action: #selector(withdrawalTapped), for: .touchUpInside)
    }
    
    @objc
    func withdrawalTapped() {
        guard let withdrawalSurvey = SBABridgeConfiguration.shared.allSurveys().first (where: { $0.identifier == .withdrawal })
            else {
                return
        }
        
        // Hide the back button so we can be sure to still be around when the response alert pops up
        self.backButton.isHidden = true
        
        // Present the withdrawal survey to get their reasons, and withdraw (or not) based on their completion (or not) of the survey
        let vc = RSDTaskViewController(taskInfo: withdrawalSurvey)
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    // MARK: RSDTaskViewControllerDelegate
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let reasonsAnswer = taskController.taskViewModel.taskResult.findAnswerResult(with: "withdrawalReason")
        (taskController as! UIViewController).dismiss(animated: true) {
            guard reason == .completed
                else {
                    // They canceled or whatnot, so turn the back button back on so they can get outta here and back to the rest of the app
                    self.backButton.isHidden = false
                    return
            }
            
            let reasonsGiven = (reasonsAnswer?.value as? [String])?.joined(separator: ", ") ?? "(No reason given)"
            
            // Withdraw all consents to research for this participant, whether currently applicable or not.
            BridgeSDK.consentManager.withdrawConsent(withReason: reasonsGiven) { (response, error) in
                if error != nil {
                    #if DEBUG
                    print("Error attempting to withdraw consent:\n\(String(describing: error))\nresponse body:\n\(String(describing: response))")
                    #endif
                    self.presentAlertWithOk(title: Localization.localizedString("WITHDRAWAL_ERROR_ALERT_TITLE"),
                                            message: Localization.localizedString("WITHDRAWAL_ERROR_ALERT_MESSAGE_BODY"),
                                            actionHandler: { (_) in
                                                DispatchQueue.main.async {
                                                    // show the back button so they can continue
                                                    self.backButton.isHidden = false
                                                }
                                                
                    })
                } else {
                    self.presentAlertWithOk(title: Localization.localizedString("WITHDRAWAL_SUCCESS_ALERT_TITLE"),
                                            message: Localization.localizedString("WITHDRAWAL_SUCCESS_ALERT_MESSAGE_BODY"),
                                            actionHandler: { (_) in
                                                BridgeSDK.authManager.signOut(completion: { (_, _, error) in
                                                    DispatchQueue.main.async {
                                                        appDelegate.showAppropriateViewController(animated: true)
                                                        self.backButton.isHidden = false
                                                        self.backButtonTapped(nil)
                                                    }
                                                })
                    })
                }
            }
        }
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // do nothing - do not store the results
    }
    
}
