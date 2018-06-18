//
//  StudyBurstCompletionViewController.swift
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

class StudyBurstCompletionViewController: UIViewController {

    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var navFooterView: RSDGenericNavigationFooterView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var statusBarBackgroundView: RSDStatusBarBackgroundView!
    
    var surveyManager: SurveyScheduleManager?

    static func instantiate() -> StudyBurstCompletionViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "StudyBurstCompletionViewController") as? StudyBurstCompletionViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupView()
    }

    func setupView() {
        
        // Populate the labels
        titleLabel.text = Localization.localizedString("STUDY_BURST_COMPLETION_TITLE")
        textLabel.text = Localization.localizedString("STUDY_BURST_COMPLETION_TEXT")
        detailLabel.text = Localization.localizedString("STUDY_BURST_COMPLETION_DETAIL")

        // Configure the next button
        navFooterView.nextButton?.addTarget(self, action: #selector(nextHit(sender:)), for: .touchUpInside)
        
        // Show or hide the next button
        navFooterView.isHidden = !hasActiveSurvey
        
        // Assign color to the status bar background view
        statusBarBackgroundView.overlayColor = UIColor.rsd_statusBarOverlayLightStyle
    }
    
    var hasActiveSurvey : Bool {
        return surveyManager?.hasSurvey ?? false
    }

    
    // MARK: Actions
    @objc
    func nextHit(sender: Any) {
        
        guard let surveyManager = surveyManager,
            let group = surveyManager.activityGroup,
            let taskInfo = group.tasks.first else {
                // Just pop to root VC
                self.navigationController?.popToRootViewController(animated: true)
                return
        }
        
        // Get our task info for the first survey, create a task and present it
        let (taskPath, _) = surveyManager.instantiateTaskPath(for: taskInfo)
        let vc = RSDTaskViewController(taskPath: taskPath)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func backHit(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}

extension StudyBurstCompletionViewController: RSDTaskViewControllerDelegate {
    
    // MARK: RSDTaskViewControllerDelegate
    open func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        // dismiss the view controller then pop to root VC
        (taskController as? UIViewController)?.dismiss(animated: true) {
            self.navigationController?.popToRootViewController(animated: true)
        }
        guard let surveyManager = surveyManager else { return }
        // Let the schedule manager handle the cleanup.
        surveyManager.taskController(taskController, didFinishWith: reason, error: error)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        guard let surveyManager = surveyManager else { return }
        surveyManager.taskController(taskController, readyToSave: taskPath)
    }
    
    func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        guard let surveyManager = surveyManager else { return nil }
        return surveyManager.taskController(taskController, asyncActionControllerFor:configuration)
    }
}
