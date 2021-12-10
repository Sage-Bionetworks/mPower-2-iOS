//
//  AppDelegate.swift
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
import BridgeAppUI
import DataTracking
import BridgeSDK
import UserNotifications
import ResearchMotion

extension RSDDesignSystem {
  public static let shared = RSDDesignSystem()
}

@UIApplicationMain
class AppDelegate: SBAAppDelegate, RSDTaskViewControllerDelegate {
    weak var smsSignInDelegate: SignInDelegate? = nil
    
    override func instantiateFactory() -> RSDFactory {
        return MP2Factory()
    }
    
    override func instantiateBridgeConfiguration() -> SBABridgeConfiguration {
        return MP2BridgeConfiguration()
    }
    
    override func instantiateColorPalette() -> RSDColorPalette? {
        let primary = RSDColorMatrix.shared.colorKey(for: .palette(.royal), shade: .medium)
        let secondary = RSDColorMatrix.shared.colorKey(for: .palette(.butterscotch), shade: .medium)
        let accent = RSDColorMatrix.shared.colorKey(for: .palette(.turquoise), shade: .medium)
        return RSDColorPalette(version: 1, primary: primary, secondary: secondary, accent: accent)
    }
    
    override func instantiateRootViewController() -> UIViewController {
        return MP2RootViewController(rootViewController: self.window?.rootViewController)
    }
    
    override var defaultOrientationLock: UIInterfaceOrientationMask {
        .portrait
    }
    
    override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {

        // Set the survey config to the subclass instance
        SBASurveyConfiguration.shared = MP2SurveyConfiguration()
        
        // TODO: syoung 03/25/2019 Refactor bridge study manager to be able to set this through the appConfig.
        RSDStudyConfiguration.shared.fullInstructionsFrequency = .monthly
        
        // Reset the badge icon on active
        // TODO: syoung 07/25/2018 Add appropriate messaging and UI/UX for highlighting notifications.
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // Set up the notification delegate
        SBAMedicationReminderManager.shared = MP2ReminderManager()
        SBAMedicationReminderManager.shared.setupNotifications()
        UNUserNotificationCenter.current().delegate = SBAMedicationReminderManager.shared
        
        let retval = super.application(application, willFinishLaunchingWithOptions: launchOptions)
        
        // The SBAAppDelegate does not refresh the app config if we already have it
        // To make sure it stays up to date, load it from web every time
        if let _ = BridgeSDK.appConfig() {
            SBABridgeConfiguration.shared.refreshAppConfig()
        }
        
        // Instantiate and load the scheduled activities and reports for the study burst.
        StudyBurstScheduleManager.shared.loadScheduledActivities()
        StudyBurstScheduleManager.shared.loadReports()
        
        // Set up the history manager to add listener for adding reports.
        let _ = HistoryDataManager.shared
        
        // Start the passive data collectors (if we have all the necessary consents, authorizations, permissions, etc.).
        // This has to be done *after* Bridge has been set up, so do it after calling super.
        PassiveCollectorManager.shared.startCollectors()

        return retval
    }
    
    func showAppropriateViewController(animated: Bool) {
        if BridgeSDK.authManager.isAuthenticated() {
            if SBAParticipantManager.shared.isConsented {
                showMainViewController(animated: animated)
            } else {
                showConsentViewController(animated: animated)
            }
        } else {
            showSignInViewController(animated: animated)
        }
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        self.showAppropriateViewController(animated: true)
        
        // Update the cached motion sensor permission state.
        RSDAuthorizationHandler.registerAdaptorIfNeeded(RSDMotionAuthorization.shared)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let components = url.pathComponents
        guard components.count >= 2,
            components[1] == BridgeSDK.bridgeInfo.studyIdentifier
            else {
                debugPrint("Asked to open an unsupported URL, punting to Safari: \(String(describing:url))")
                UIApplication.shared.open(url)
                return true
        }
        
        if components.count == 4,
            components[2] == "phoneSignIn" {
            let token = components[3]
            
            // pass the token to the SMS sign-in delegate, if any
            if smsSignInDelegate != nil {
                smsSignInDelegate?.signIn(token: token)
                return true
            } else {
                // there's no SMS sign-in delegate so try to get the phone info from the participant record.
                BridgeSDK.participantManager.getParticipantRecord { (record, error) in
                    guard let participant = record as? SBBStudyParticipant, error == nil else { return }
                    guard let phoneNumber = participant.phone?.number,
                        let regionCode = participant.phone?.regionCode,
                        !phoneNumber.isEmpty,
                        !regionCode.isEmpty else {
                            return
                    }
                    
                    BridgeSDK.authManager.signIn(withPhoneNumber:phoneNumber, regionCode:regionCode, token:token, completion: { (task, result, error) in
                        DispatchQueue.main.async {
                            if (error as NSError?)?.code == SBBErrorCode.serverPreconditionNotMet.rawValue {
                                self.showConsentViewController(animated: true)
                            } else if error == nil {
                                
                                // Now that we have a user who is signed in via phone number, check the region code to
                                // see if we need to add the heart snapshot data group.
                                // Heart Snapshot tasks are only enabled for the Netherlands region
                                if (regionCode == SignInTaskViewController.NETHERLANDS_REGION_CODE) {
                                    BridgeSDK.participantManager.add(toDataGroups: ["show_heartsnapshot"], completion: nil)
                                }
                                
                                self.showAppropriateViewController(animated: true)
                            } else {
                                #if DEBUG
                                print("Error attempting to sign in with SMS link while not in registration flow:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
                                #endif
                                let title = Localization.localizedString("SIGN_IN_ERROR_TITLE")
                                var message = Localization.localizedString("SIGN_IN_ERROR_BODY_GENERIC_ERROR")
                                if (error! as NSError).code == SBBErrorCode.serverNotAuthenticated.rawValue {
                                    message = Localization.localizedString("SIGN_IN_ERROR_BODY_USED_TOKEN")
                                }
                                self.presentAlertWithOk(title: title, message: message, actionHandler: { (_) in
                                    self.showSignInViewController(animated: true)
                                })
                            }
                        }
                    })
                }
            }
        } else if components[2] == "study-burst" {
            // TODO: emm 2018-08-27 take them to the study burst flow instead
            self.showAppropriateViewController(animated: true)
        } else {
            // if we don't specifically handle the URL, but the path starts with the study identifier, just bring them into the app
            // wherever it would normally open to from closed.
            self.showAppropriateViewController(animated: true)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let url = userActivity.webpageURL else {
            debugPrint("Unrecognized userActivity passed to app delegate:\(String(describing: userActivity))")
            return false
        }
        return self.application(application, open: url)
    }
    
    func showMainViewController(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        guard let storyboard = openStoryboard("Main"),
            let vc = storyboard.instantiateInitialViewController()
            else {
            fatalError("Failed to instantiate initial view controller in the main storyboard.")
        }
        
        // Check that the engagement groups have been set before transitioning.
        StudyBurstScheduleManager.shared.setEngagementGroupsIfNeeded()
        
        // Show the main view controller.
        self.transition(to: vc, state: .main, animated: true)
        
        // start the passive collectors now in case they weren't started at launch
        PassiveCollectorManager.shared.startCollectors()
    }
    
    func showSignInViewController(animated: Bool) {
        guard self.rootViewController?.state != .onboarding else { return }
        let vc = SignInTaskViewController()
        vc.delegate = self
        self.transition(to: vc, state: .onboarding, animated: true)
    }
    
    func showConsentViewController(animated: Bool) {
        guard self.rootViewController?.state != .consent else { return }
        let vc = ConsentViewController()
        // TODO: emm 2018-05-11 put this in BridgeInfo or AppConfig?
        vc.url = URL(string: "https://parkinsonmpower.org/study/intro")
        self.transition(to: vc, state: .consent, animated: true)
    }
    
    func openStoryboard(_ name: String) -> UIStoryboard? {
        return UIStoryboard(name: name, bundle: nil)
    }
    
    
    // MARK: RSDTaskViewControllerDelegate
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        guard BridgeSDK.authManager.isAuthenticated() else { return }
        showAppropriateViewController(animated: true)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
    }
    
    // MARK: SBBBridgeErrorUIDelegate
    
    override func handleUserNotConsentedError(_ error: Error, sessionInfo: Any, networkManager: SBBNetworkManagerProtocol?) -> Bool {
        self.showConsentViewController(animated: true);
        return true;
    }
    
}

class MP2RootViewController : SBARootViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
}
