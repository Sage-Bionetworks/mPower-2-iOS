//
//  TrackingViewController.swift
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
import MotorControl
import Research
import ResearchUI

class TrackingViewController: UIViewController {
    
    
    @IBOutlet weak var actionBarView: UIView!
    @IBOutlet weak var actionBarTitleLabel: UILabel!
    @IBOutlet weak var actionBarDetailsLabel: UILabel!
    @IBOutlet weak var progressCircleView: ProgressCircleView!
    @IBOutlet weak var taskBrowserContainer: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var taskBrowserBottomConstraint: NSLayoutConstraint!
    
    public var shouldShowActionBar = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        updateActionBar()
        updateProgressCircle()
        
        // TODO: jbruhin 5-1-18 find better way to handle this, including for the other 3 main VCs
        let customTabBarItem:UITabBarItem = UITabBarItem(title: "Tracking",
                                                         image: UIImage(named: "TabTracking _selected")?.withRenderingMode(UIImageRenderingMode.alwaysOriginal),
                                                         selectedImage: UIImage(named: "TabTracking _selected"))
        tabBarItem = customTabBarItem
    }
    
    func setupView() {
        
        // Add our task browser view controller
        let browser = TaskBrowserViewController()
        browser.view.translatesAutoresizingMaskIntoConstraints = false
        addChildViewController(browser)
        taskBrowserContainer.addSubview(browser.view)
        browser.view.rsd_alignAllToSuperview(padding: 0.0)
        
        // Configure actionBarView
        actionBarView.layer.cornerRadius = 4.0
        actionBarView.layer.masksToBounds = true
        
        // TODO: jbruhin 5-1-18 update 'welcome' text dynamically
    }
    
    func updateActionBar() {
        // TODO: jbruhin 5-1-18 will be a data source for this at some point
        actionBarTitleLabel.text = "Study Burst"
        actionBarDetailsLabel.text = "4 ACTIVITIES TO DO"
        
        // TODO: jbruhin 5-1-18 will need to make the following dynamic based on...something
        actionBarView.isHidden = !shouldShowActionBar
        if shouldShowActionBar {
            // Add some top inset on the tableView
            let inset = actionBarView.frame.origin.y + actionBarView.frame.size.height
            tableView.contentInset = UIEdgeInsets(top: inset, left: 0.0, bottom: 0.0, right: 0.0)
        }
        //
    }
    
    func updateProgressCircle() {
        // TODO: jbruhin 5-1-18 will be a data source for this at some point
        progressCircleView.displayDay(count: 14)
    }
    
    // MARK: Actions
    @IBAction func actionBarTapped(_ sender: Any) {
        // TODO: jbruhin 5-1-18 implement
    }
}

extension TrackingViewController: RSDTaskViewControllerDelegate {

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

