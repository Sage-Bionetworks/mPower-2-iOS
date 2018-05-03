//
//  TrackingViewController.swift
//  mPower2
//
//  Created by Josh Bruhin on 5/1/18.
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//

import UIKit
import MotorControl
import Research
import ResearchUI

class TrackingViewController: UIViewController, RSDTaskViewControllerDelegate {
    
    
    @IBOutlet weak var actionBarView: UIView!
    @IBOutlet weak var actionBarTitleLabel: UILabel!
    @IBOutlet weak var actionBarDetailsLabel: UILabel!
    @IBOutlet weak var progressCircleView: ActionBarProgressCircleView!
    @IBOutlet weak var taskBrowserContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let browser = TaskBrowserViewController()
        browser.view.translatesAutoresizingMaskIntoConstraints = false
        addChildViewController(browser)
        taskBrowserContainer.addSubview(browser.view)
        browser.view.rsd_alignAllToSuperview(padding: 0.0)
    }
    
    // MARK: Actions
    @IBAction func actionBarTapped(_ sender: Any) {
        
    }
    

    // MARK: RSTTaskViewControllerDelegate
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        // dismiss the view controller
        (taskController as? UIViewController)?.dismiss(animated: true) {
        }
        
        print("\n\n=== Completed: \(reason) error:\(String(describing: error))")
        print(taskController.taskPath.result)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        
    }
    
    func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
    }
}

class ActionBarProgressCircleView: ProgressCircleView {
    
}
