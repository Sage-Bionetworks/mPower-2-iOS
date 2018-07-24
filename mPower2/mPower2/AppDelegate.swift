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
import BridgeApp
import BridgeSDK
import UserNotifications

@UIApplicationMain
class AppDelegate: SBAAppDelegate, RSDTaskViewControllerDelegate {
    
    weak var smsSignInDelegate: SignInDelegate? = nil
    
    var userSessionInfo: SBBUserSessionInfo?
    
    override func instantiateFactory() -> RSDFactory {
        return MP2Factory()
    }
    
    override func instantiateBridgeConfiguration() -> SBABridgeConfiguration {
        return MP2BridgeConfiguration()
    }
    
    override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
        NotificationCenter.default.addObserver(forName: .sbbUserSessionUpdated, object: nil, queue: .main) { (notification) in
            guard let info = notification.userInfo?[kSBBUserSessionInfoKey] as? SBBUserSessionInfo else {
                fatalError("Expected notification userInfo to contain a user session info object")
            }
            self.userSessionInfo = info
        }
        
        // Instantiate and load the scheduled activities for the study burst.
        StudyBurstScheduleManager.shared.loadScheduledActivities()
        
        // Reset the badge icon on active
        // TODO: syoung 07/25/2018 Add appropriate messaging and UI/UX for highlighting notifications.
        UIApplication.shared.applicationIconBadgeNumber = 0

        return super.application(application, willFinishLaunchingWithOptions: launchOptions)
    }
    
    func showAppropriateViewController(animated: Bool) {
        if BridgeSDK.authManager.isAuthenticated() {
            if userSessionInfo?.consentedValue ?? false {
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
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        guard let url = userActivity.webpageURL else {
            debugPrint("Unrecognized userActivity passed to app delegate:\(String(describing: userActivity))")
            return false
        }
        let components = url.pathComponents
        guard components.count == 4,
            url.host! == "ws.sagebridge.org",
            components[1] == BridgeSDK.bridgeInfo.studyIdentifier,
            components[2] == "phoneSignIn"
            else {
                debugPrint("Asked to open an unsupported URL, punting to Safari: \(String(describing:userActivity.webpageURL))")
                UIApplication.shared.open(url)
                return true
        }
        
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
                    if (error as NSError?)?.code == SBBErrorCode.serverPreconditionNotMet.rawValue {
                        DispatchQueue.main.async {
                            // TODO emm 2018-05-04 signed in but not consented -- go to consent flow
                        }
                    } else if error != nil {
                        // TODO emm 2018-05-04 handle error from Bridge
                        debugPrint("Error attempting to sign in with SMS link while not in registration flow:\n\(String(describing: error))\n\nResult:\n\(String(describing: result))")
                    }
                })
            }
        }
        
        return true
    }

    func showMainViewController(animated: Bool) {
        guard self.rootViewController?.state != .main else { return }
        guard let storyboard = openStoryboard("Main"),
            let vc = storyboard.instantiateInitialViewController()
            else {
            fatalError("Failed to instantiate initial view controller in the main storyboard.")
        }
        self.transition(to: vc, state: .main, animated: true)
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
        // TODO emm 2018-05-11 put this in BridgeInfo or AppConfig?
        vc.url = URL(string: "http://mpower.sagebridge.org/study/intro")
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
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
    }
    
    func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
    }
    
}

