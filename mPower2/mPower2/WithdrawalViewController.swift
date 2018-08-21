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

import BridgeApp

class WithdrawalViewController: UIViewController {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    @IBOutlet var withdrawalButton: RSDRoundedButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // This screen will be shown underneath the screen that actually withdraws from the study,
        // so check if we are returning to it after we have already withdrawn, or are not signed in
        if !BridgeSDK.authManager.isAuthenticated() {
            self.dismiss(animated: true, completion: nil)
        } else {
            setupNavigationBar()
        }
    }
    
    func setupNavigationBar() {
        self.navigationController?.navigationBar.isTranslucent = false
        
        self.navigationController?.navigationBar.topItem!.title = Localization.localizedString("WITHDRAWAL_STUDY_PARTICIPATION_TITLE")
        
        let leftBarButtonItem = UIBarButtonItem(title: Localization.localizedString("BUTTON_CANCEL"), style: .plain, target: self, action: #selector(cancelTapped))
        leftBarButtonItem.tintColor = UIColor.white
        self.navigationItem.leftBarButtonItem = leftBarButtonItem
    }
    
    @objc
    func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func setupViews() {
        
        self.view.backgroundColor = UIColor.primaryTintColor
        
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
        withdrawalButton.setTitleColor(UIColor.appAlertRed, for: .normal)
        withdrawalButton.backgroundColor = UIColor.white
        withdrawalButton.addTarget(self, action: #selector(withdrawalTapped), for: .touchUpInside)
    }
    
    @objc
    func withdrawalTapped() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
        let consentStatuses = appDelegate.userSessionInfo?.consentStatuses as? [ String : SBBConsentStatus ]
            else {
                return
        }
        
        // Withdraw them from all subpopulations whose current consent they have signed.
        let withdrawGroup = DispatchGroup()
        var errorWithdrawing: Bool = false
        for (subpopulationGuid, consentStatus) in consentStatuses {
            if consentStatus.signedMostRecentConsentValue && !errorWithdrawing {
                withdrawGroup.enter()
                BridgeSDK.consentManager.withdrawConsent(forSubpopulation: subpopulationGuid, withReason: "chose to withdraw from app via profile tab") { (response, error) in
                    if error != nil {
                        errorWithdrawing = true
                    }
                    withdrawGroup.leave()
                }
            }
        }
        withdrawGroup.notify(queue: DispatchQueue.main) {
            // Note that we use the current root view controller to present these alerts because the participant may have left this view controller by the time
            // the server call(s) to withdraw consent has (have) completed.
            if errorWithdrawing {
                appDelegate.rootViewController?.presentAlertWithOk(title: Localization.localizedString("WITHDRAWAL_ERROR_ALERT_TITLE"),
                                                                  message: Localization.localizedString("WITHDRAWAL_ERROR_ALERT_MESSAGE_BODY"),
                                                                  actionHandler: nil)
            } else {
                appDelegate.rootViewController?.presentAlertWithOk(title: Localization.localizedString("WITHDRAWAL_SUCCESS_ALERT_TITLE"),
                                                                  message: Localization.localizedString("WITHDRAWAL_SUCCESS_ALERT_MESSAGE_BODY"),
                                                                  actionHandler: { (_) in
                                                                    appDelegate.showAppropriateViewController(animated: true)
                })
            }
        }
    }
}
