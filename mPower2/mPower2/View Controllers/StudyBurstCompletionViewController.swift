//
//  StudyBurstCompletionViewController.swift
//  mPower2
//
//  Created by Josh Bruhin on 6/7/18.
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
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
