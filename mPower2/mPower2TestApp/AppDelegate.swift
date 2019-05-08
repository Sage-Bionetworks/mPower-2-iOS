//
//  AppDelegate.swift
//  mPower2TestApp
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
import BridgeSDK
import BridgeApp
import BridgeSDK_Test

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    final class var shared: UIApplicationDelegate? {
        return UIApplication.shared.delegate
    }

    weak var smsSignInDelegate: SignInDelegate? = nil
    
    var userSessionInfo: SBBUserSessionInfo? = nil

    var testHarness: SBBBridgeTestHarness?

    var window: UIWindow?
        
    let colorPalette:  RSDColorPalette = {
        let primary = RSDColorMatrix.shared.colorKey(for: .palette(.royal), shade: .medium)
        let secondary = RSDColorMatrix.shared.colorKey(for: .palette(.butterscotch), shade: .medium)
        let accent = RSDColorMatrix.shared.colorKey(for: .palette(.turquoise), shade: .medium)
        return RSDColorPalette(version: 1, primary: primary, secondary: secondary, accent: primary)
    }()
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        RSDStudyConfiguration.shared.colorPalette = colorPalette
        RSDStudyConfiguration.shared.fullInstructionsFrequency = .monthly
        
        // Set up localization.
        let mainBundle = LocalizationBundle(bundle: Bundle.main, tableName: "mPower2")
        Localization.insert(bundle: mainBundle, at: 0)
     
        testHarness = SBBBridgeTestHarness(studyIdentifier: "sage-mpower-2-test")
        
        let activityManager = ActivityManager()
        
        // NOTE: syoung 06/28/2018 You can set different study setup objects to test different states.
        activityManager.studySetup = .day9_tasksFinished
        
        SBBComponentManager.registerComponent(activityManager, for: SBBActivityManager.self)
        activityManager.buildSchedules()
        
        let participantManager = ParticipantManager()
        participantManager.setup(with: activityManager.studySetup)
        SBBComponentManager.registerComponent(participantManager, for: SBBParticipantManager.self)
        
        SurveyReference.all.forEach {
            testHarness!.setJSONWithFile($0.identifier.stringValue,
                                         forEndpoint: $0.endpoint,
                                         andMethod: "GET")
        }
        
        SBABridgeConfiguration.shared = MP2BridgeConfiguration()
        SBABridgeConfiguration.shared.setupBridge(with: MP2Factory()) {
            SBABridgeConfiguration.shared.refreshAppConfig()
        }
        
        self.testHarness!.post(participantManager.participant)
        
        SBASurveyConfiguration.shared = MP2SurveyConfiguration()
        
        // Instantiate and load the scheduled activities and reports for the study burst.
        StudyBurstScheduleManager.shared.loadScheduledActivities()
        StudyBurstScheduleManager.shared.loadReports()
        
        return true
    }
    
    func showAppropriateViewController(animated: Bool) {
    }
    
    func showSignInViewController(animated: Bool) {
    }
}

