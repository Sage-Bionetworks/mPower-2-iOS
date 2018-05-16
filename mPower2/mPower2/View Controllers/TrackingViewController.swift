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

@IBDesignable
class TrackingViewController: UIViewController {
    
    private let kTaskBrowserSegueIdentifier = "TaskBrowserSegue"
    
    @IBOutlet weak var actionBarView: UIView!
    @IBOutlet weak var actionBarTitleLabel: UILabel!
    @IBOutlet weak var actionBarDetailsLabel: UILabel!
    @IBOutlet weak var progressCircleView: ProgressCircleView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var taskBrowserContainerView: UIView!
    
    @IBOutlet weak var taskBrowserTopConstraint: NSLayoutConstraint!
    
    
    var dragDistance: CGFloat = 0.0
    var taskBrowserVisible = true {
        didSet {
            updateTaskBrowserPosition(animated: true)
        }
    }
    
    public var shouldShowActionBar = true
    
    // TODO: jbruhin 5-10-18 - replace this with actual model
    var completedTaskGroups: [[RSDTaskInfoObject]] = {
        let taskGroups = [["Symptoms", "Symptoms", "Symptoms"],
                          ["Medication", "Medication"],
                          ["Triggers", "Triggers", "Triggers", "Triggers"],
                          ["Tremor"]]
        var taskInfosGroups = [[RSDTaskInfoObject]]()
        for tasks in taskGroups {
            var taskInfos = [RSDTaskInfoObject]()
            tasks.forEach({
                var taskInfo = RSDTaskInfoObject(with: $0)
                taskInfo.title = $0
                taskInfo.resourceTransformer = RSDResourceTransformerObject(resourceName: $0)
                taskInfos.append(taskInfo)
            })
            taskInfosGroups.append(taskInfos)
        }
        return taskInfosGroups
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        
        // TODO: jbruhin 5-1-18 find better way to handle this, including for the other 3 main VCs
        let customTabBarItem:UITabBarItem = UITabBarItem(title: "Tracking",
                                                         image: UIImage(named: "TabTracking _selected")?.withRenderingMode(UIImageRenderingMode.alwaysOriginal),
                                                         selectedImage: UIImage(named: "TabTracking _selected"))
        tabBarItem = customTabBarItem
    }
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setupView()
    }
    
    func taskGroups() -> [RSDTaskGroup] {
        // TODO: jbruhin 5-1-18 obtain task model from the proper source?? Model also needs more tasks
        // and tasks may need more data, like icon images
        let taskGroups: [RSDTaskGroup] = {
            let activeTaskGroup : RSDTaskGroup = {
                let taskInfos = MCTTaskIdentifier.all().map { MCTTaskInfo($0) }
                var taskGroup = RSDTaskGroupObject(with: "Measuring", tasks: taskInfos)
                taskGroup.title = "Measuring"
                return taskGroup
            }()
            let trackingTaskGroup : RSDTaskGroup = {
                
                var taskInfos = [RSDTaskInfoObject]()
                ["Symptoms", "Medication", "Triggers", "Medication", "Medication"].forEach({
                    var taskInfo = RSDTaskInfoObject(with: $0)
                    taskInfo.title = $0
                    taskInfo.resourceTransformer = RSDResourceTransformerObject(resourceName: $0)
                    // Get the task icon for this taskIdentifier
                    do {
                        taskInfo.icon = try RSDImageWrapper(imageName: "\(taskInfo.identifier)TaskIcon")
                    } catch let err {
                        print("Failed to load the task icon. \(err)")
                    }
                    taskInfos.append(taskInfo)
                })
                
                var taskGroup = RSDTaskGroupObject(with: "Tracking", tasks: taskInfos)
                taskGroup.title = "Tracking"
                return taskGroup
            }()
            
            return [trackingTaskGroup, activeTaskGroup]
        }()
        return taskGroups
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kTaskBrowserSegueIdentifier,
            let taskBrowser = segue.destination as? TaskBrowserViewController {
            taskBrowser.taskGroups = taskGroups()
        }
    }
    
    func setupView() {
        
        // Initial setup
        setupWelcomeText()
        actionBarView.layer.cornerRadius = 4.0
        actionBarView.layer.masksToBounds = true
                
        // Add pan gesture to the task browser container
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragTaskBrowser(sender:)))
        taskBrowserContainerView.addGestureRecognizer(pan)
        
        // update variable items
        updateTaskBrowserPosition(animated: false)
        updateActionBar()
        updateProgressCircle()
    }
    
    func setupWelcomeText() {
        // TODO: jbruhin 5-1-18 update 'welcome' text dynamically based on time of day
    }
    
    func updateTaskBrowserPosition(animated: Bool) {
        dragDistance = 0.0
        taskBrowserTopConstraint.constant = taskBrowserTopDistanceWhen(visible: taskBrowserVisible)
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
        }
    }

    func updateActionBar() {
        // TODO: jbruhin 5-1-18 will be a data source for this at some point
        actionBarTitleLabel.text = "Study Burst"
        actionBarDetailsLabel.text = "4 ACTIVITIES TO DO"
        
        // TODO: jbruhin 5-1-18 will need to make the following dynamic based on...something
        actionBarView.isHidden = !shouldShowActionBar
        if shouldShowActionBar {
            // Inset the top of the tableView to accommodate actionBar
            let inset = actionBarView.frame.origin.y + actionBarView.frame.size.height
            tableView.contentInset = UIEdgeInsets(top: inset, left: 0.0, bottom: 0.0, right: 0.0)
        }
    }
    
    func updateProgressCircle() {
        // TODO: jbruhin 5-1-18 will be a data source for this at some point
        progressCircleView.displayDay(count: 14)
    }
    
    
    // MARK: Actions
    @IBAction func actionBarTapped(_ sender: Any) {
        // TODO: jbruhin 5-1-18 implement
        presentAlertWithOk(title: "Not implemented yet.", message: "", actionHandler: nil)
    }
}

extension TrackingViewController: UITableViewDelegate, UITableViewDataSource {
    // MARK: UITableView Datasource
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return completedTaskGroups.count
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell =  tableView.dequeueReusableCell(withIdentifier: "TrackingTableViewCell", for: indexPath) as! TrackingTableViewCell
        if let firstTask = completedTaskGroups[indexPath.row].first {
            cell.iconView.image = firstTask.iconSmall
            // Update our label text, but keep the attributes defined in Interface Builder
            let newString = String(format: "%@ %@", String(describing: completedTaskGroups[indexPath.row].count), firstTask.pluralTerm)
            let newAttributedString = NSMutableAttributedString(attributedString: cell.countLabel.attributedText ?? NSAttributedString(string: ""))
            newAttributedString.mutableString.setString(newString)
            cell.countLabel.attributedText = newAttributedString
        }
        
        return cell
    }
    
    // MARK: UITableView Delegate
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: jbruhin 5-10-18 implement??
        presentAlertWithOk(title: "Should this do something??", message: "", actionHandler: nil)
    }
}

extension TrackingViewController {
    
    // MARK: TaskBrowserViewController management
    
    @objc func dragTaskBrowser(sender: UIPanGestureRecognizer) {
        
        if sender.state == .ended {
            updateTaskBrowserPosition(animated: true)
        }
        else {
            let translation = sender.translation(in: taskBrowserContainerView)
            let newDragDistance = dragDistance + translation.y
            let newPoint = taskBrowserTopDistanceWhen(visible: taskBrowserVisible) + newDragDistance
            
            if shouldDrag(dragPoint: newPoint) {
                
                if !taskBrowserVisible && shouldOpenTaskBrowser(dragPoint: newPoint) {
                    taskBrowserVisible = true
                    return
                }
                
                if taskBrowserVisible && shouldCloseTaskBrowser(dragPoint: newPoint) {
                    taskBrowserVisible = false
                    return
                }
                
                dragDistance = newDragDistance
                taskBrowserTopConstraint.constant = newPoint
                sender.setTranslation(CGPoint.zero, in: self.view)
            }
        }
    }
    
    func shouldOpenTaskBrowser(dragPoint: CGFloat) -> Bool {
        // If the drag point is more than 1/3 of the way from closed to open, then we open
        let contentHeight = taskBrowserHeight() - TaskBrowserViewController.tabsHeight()
        let triggerPoint = taskBrowserTopDistanceWhen(visible: true) + contentHeight * 2/3
        return dragPoint < triggerPoint
    }
    
    func shouldCloseTaskBrowser(dragPoint: CGFloat) -> Bool {
        // If the drag point is more than 1/3 of the way from open to closed, then we close
        let contentHeight = taskBrowserHeight() - TaskBrowserViewController.tabsHeight()
        let triggerPoint = taskBrowserTopDistanceWhen(visible: true) + contentHeight * 1/3
        return dragPoint > triggerPoint
    }
    
    func shouldDrag(dragPoint: CGFloat) -> Bool {
        // Don't drag if we've gone beyond our closed or open positions
        let closedPoint = taskBrowserTopDistanceWhen(visible: false)
        let openedPoint = taskBrowserTopDistanceWhen(visible: true)
        return dragPoint < closedPoint && dragPoint > openedPoint
    }
    
    func taskBrowserTopDistanceWhen(visible: Bool) -> CGFloat {
        return view.bounds.height - taskBrowserHeightWhen(visible: visible) - (tabBarController?.tabBar.bounds.height ?? 0.0)
    }
    
    func taskBrowserHeightWhen(visible: Bool) -> CGFloat {
        if visible {
            return taskBrowserHeight()
        }
        else {
            return TaskBrowserViewController.tabsHeight()
        }
    }
    
    func taskBrowserHeight() -> CGFloat {
        if let heightConstraint = taskBrowserContainerView.rsd_constraint(for: .height, relation: .equal) {
            return heightConstraint.constant
        }
        return 0.0
    }
}

class TrackingTableViewCell: UITableViewCell {
    
    // TODO: jbruhin 5-10-18 - optimize positioning of content for different screen sizes
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var countLabel: UILabel!
    
}

extension RSDTaskInfoObject {
    var iconSmall: UIImage? {
        get {
            return UIImage(named: "\(self.identifier)TaskIconSmall")
        }
    }
    var pluralTerm: String {
        get {
            return Localization.localizedString("TASK_PLURAL_TERM_FOR_\(identifier.uppercased())")
        }
    }
}
