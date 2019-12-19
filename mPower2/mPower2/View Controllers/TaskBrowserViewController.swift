//
//  TaskBrowserViewController.swift
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
import Research
import MotorControl
import BridgeApp

protocol TaskBrowserViewControllerDelegate {
    func taskBrowserToggleVisibility()
    func taskBrowserTabSelected()
    func taskBrowserDidLayoutSubviews()
    func taskBrowserDidFinish(task: RSDTaskViewModel, reason: RSDTaskFinishReason)
}

class TaskBrowserViewController: UIViewController, RSDTaskViewControllerDelegate, TaskBrowserTabViewDelegate {
    
    // Used by our potential parent VC to show/hide our collectionView
    class func tabsHeight() -> CGFloat {
        return 50.0
    }
    
    public var delegate: TaskBrowserViewControllerDelegate?
    public var scheduleManagers: [ActivityGroupScheduleManager]? {
        didSet {
            setupManagersIfNeeded()
        }
    }
    
    open var shouldShowTopShadow: Bool {
        return true
    }
    
    open var shouldShowTabs: Bool {
        guard let scheduleManagers = scheduleManagers else {
            return false
        }
        return scheduleManagers.count > 1
    }
    
    open var tasks: [ScheduledTask] {
        return selectedScheduleManager?.orderedTasks ?? []
    }
    
    func scheduleManager(with identifier: String) -> ActivityGroupScheduleManager? {
        return scheduleManagers?.first(where: { $0.identifier == identifier })
    }

    /// Check the selected schedule managers and set to the first if not already set.
    private var selectedScheduleManager: ActivityGroupScheduleManager! {
        get {
            if _selectedScheduleManager == nil {
                _selectedScheduleManager = scheduleManagers?.first
            }
            return _selectedScheduleManager
        }
        set {
            _selectedScheduleManager = newValue
        }
    }
    private var _selectedScheduleManager: ActivityGroupScheduleManager!
    
    @IBOutlet weak var tabButtonStackView: UIStackView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var ruleView: UIView!
    @IBOutlet weak var shadowView: RSDShadowGradient!
    @IBOutlet weak var tabsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var unlockMessageLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        unlockMessageLabel?.isHidden = areTasksEnabled
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let delegate = delegate else {
            return
        }
        delegate.taskBrowserDidLayoutSubviews()
    }
    
    func setupView() {
        
        let designSystem = RSDDesignSystem()
        
        // Remove existing managed subviews from tabBar stackView
        tabButtonStackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        setupManagersIfNeeded()
        
        // set the tabView height and hide or show it, along with the rule just below
        tabsViewHeightConstraint.constant = shouldShowTabs ? TaskBrowserViewController.tabsHeight() : 0.0
        tabButtonStackView.isHidden = !shouldShowTabs
        ruleView.isHidden = !shouldShowTabs

        // Hide or show our shadow and rule views
        shadowView.isHidden = !shouldShowTopShadow
        
        unlockMessageLabel?.text = Localization.localizedString("UNLOCK_MESSAGE_FINISH_STUDY_BURST")
        unlockMessageLabel?.textColor = designSystem.colorRules.textColor(on: designSystem.colorRules.backgroundLight, for: .largeHeader)
        unlockMessageLabel?.isHidden = true

        // Reload our data
        collectionView.reloadData()
    }
    
    func setupManagersIfNeeded() {
        guard !_managersLoaded, self.isViewLoaded, let managers = self.scheduleManagers else { return }
        _managersLoaded = true
        // Create tabs for each schedule manager
        managers.forEach { (manager) in
            manager.reloadData()
            let tabView = TaskBrowserTabView(frame: .zero, taskGroupIdentifier: manager.identifier)
            tabView.title = manager.activityGroup?.title
            tabView.accessibilityLabel = tabView.title
            tabView.accessibilityIdentifier = tabView.title
            tabView.delegate = self
            tabView.isSelected = (manager.identifier == selectedScheduleManager.identifier)
            tabButtonStackView.addArrangedSubview(tabView)
            NotificationCenter.default.addObserver(forName: .SBAUpdatedScheduledActivities, object: manager, queue: OperationQueue.main) { (notification) in
                self.collectionView.reloadData()
            }
        }
    }
    private var _managersLoaded = false
    
    func startTask(for taskInfo: RSDTaskInfo) {
        let (taskViewModel, _) = selectedScheduleManager.instantiateTaskViewModel(for: taskInfo)
        let vc = RSDTaskViewController(taskViewModel: taskViewModel)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    // MARK: Instance methods
    public func showSelectionIndicator(visible: Bool) {
        // Iterate all of our tab views and change alpha
        tabButtonStackView.arrangedSubviews.forEach { (subView) in
            if let tabView = subView as? TaskBrowserTabView {
                tabView.rule.alpha = visible ? 1.0 : 0.0
            }
        }
    }
    
    // MARK: RSDTaskViewControllerDelegate
    open func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {

        // Inform our delegate that we finished a task
        self.delegate?.taskBrowserDidFinish(task: taskController.taskViewModel, reason: reason)

        // dismiss the view controller
        (taskController as? UIViewController)?.dismiss(animated: true, completion: nil)
        
        // Let the schedule manager handle the cleanup.
        selectedScheduleManager.taskController(taskController, didFinishWith: reason, error: error)
        
        // Reload the collection view
        self.collectionView.reloadData()
        self.unlockMessageLabel?.isHidden = areTasksEnabled
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        selectedScheduleManager.taskController(taskController, readyToSave: taskViewModel)
    }

    // MARK: TaskBrowserTabViewDelegate
    func taskGroupSelected(identifier: String) {
        
        guard let newManager = scheduleManager(with: identifier) else {
            return
        }
        
        // If this is the currently selected task group - meaning the user tapped the selected tab,
        // we tell our delegate to toggle visibility
        if newManager.identifier == selectedScheduleManager?.identifier,
            let delegate = delegate {
            delegate.taskBrowserToggleVisibility()
        }
        else {
            // Save our selected task group and reload collection
            selectedScheduleManager = newManager
            collectionView.reloadData()
            unlockMessageLabel?.isHidden = areTasksEnabled
            
            // Now update the isSelected value of all the tabs
            tabButtonStackView.arrangedSubviews.forEach {
                if let tabView = $0 as? TaskBrowserTabView {
                    tabView.isSelected = tabView.taskGroupIdentifier == identifier
                }
            }
            
            // Tell our delegate that a tab was selected. It may be that we are hidden and the
            // parent view might like to show us again
            if let delegate = delegate {
                delegate.taskBrowserTabSelected()
            }
        }
    }
    
    var areTasksEnabled: Bool {
        return StudyBurstScheduleManager.shared.isCompletedForToday ||
            (selectedScheduleManager.activityGroup!.identifier == RSDIdentifier.trackingTaskGroup)
    }
}

extension TaskBrowserViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    /*
     The objective is to optimize the layout of the cells for different screen sizes and different collection quantities.
     For instance, if all cells will fit in the collectionView.bounds - so user doesn't have to scroll - then let's
     center the cells horizontally and vertically. If they won't all fit and the user will need to scroll, then let's
     space them so there is a portion of a row or column (depending on scroll direction) positioned partly on screen and
     partly off screen so the user has a visual queue to scroll.
     */
    
    @objc
    open var collectionCellIdentifier: String {
        return "TaskCollectionViewCell"
    }
    
    @objc
    open var minCellHorizontalSpacing: CGFloat {
        return 5.0
    }
    @objc
    open var minCellVerticalSpacing: CGFloat {
        return 5.0
    }
    
    func doAllCellsFit() -> Bool {
        return numberOfRowsThatFit() * numberOfColumnsThatFit() >= tasks.count
    }
    
    func numberOfRowsThatFit() -> Int {
        guard let flowLayout = flowLayout() else {
            return 0
        }
        let availableHeight: CGFloat = collectionView.bounds.height - minCellVerticalSpacing
        let cellHeightPlusMinSpacing: CGFloat = flowLayout.itemSize.height + minCellVerticalSpacing
        return Int(floorf(Float(availableHeight / cellHeightPlusMinSpacing)))
    }
    
    func numberOfColumnsThatFit() -> Int {
        guard let flowLayout = flowLayout() else {
            return 0
        }
        let availableWidth: CGFloat = collectionView.bounds.width - minCellHorizontalSpacing
        let cellWidthPlusMinSpacing: CGFloat = flowLayout.itemSize.width + minCellHorizontalSpacing
        return Int(floorf(Float(availableWidth / cellWidthPlusMinSpacing)))
    }
    
    func flowLayout() -> UICollectionViewFlowLayout? {
        return collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    // MARK: UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tasks.count
    }
    
    // MARK: UICollectionViewDelegate
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collectionCellIdentifier, for: indexPath) as? TaskCollectionViewCell
        let scheduledTask = tasks[indexPath.row]
        let task = scheduledTask.taskInfo
        cell?.image = task.iconWhite
        cell?.title = task.title?.uppercased()
        cell?.alpha = areTasksEnabled ? 1.0 : 0.35
        cell?.isCompleted = false
        return cell ?? UICollectionViewCell()
    }
    
    @objc
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // Get our task and present it
        startTask(for: tasks[indexPath.row].taskInfo)
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        guard let flowLayout = flowLayout() else {
            return 0.0
        }
        return flowLayout.scrollDirection == .horizontal ? horizontalSpacing() : verticalSpacing()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.init(top: verticalSpacing(), left: horizontalSpacing(), bottom: verticalSpacing(), right: horizontalSpacing())
    }
    
    open func horizontalSpacing() -> CGFloat {
        guard let flowLayout = flowLayout() else {
                return minCellHorizontalSpacing
        }
        
        if doAllCellsFit() || flowLayout.scrollDirection == .vertical {
            // Use a spacing value that centers them horizontally. First figure out how many columns we actually have
            let rawColCount = ceilf(Float(tasks.count) / Float(numberOfRowsThatFit()))
            let colCount: CGFloat = {
                if tasks.count > numberOfColumnsThatFit() {
                    return CGFloat([CGFloat(rawColCount), CGFloat(numberOfColumnsThatFit())].min() ?? 0)            }
                else {
                    return CGFloat(tasks.count)
                }
            }()
            return (collectionView.bounds.width - (colCount * flowLayout.itemSize.width)) / (colCount + 1.0)
        }
        else {
            // We want the last visible cells on the right side of the view to be just partially visible to inform the
            // user that they can scroll to the right to get more. So we take the last row that will fit and 'move it'
            // half way off screen. If onle one column fits, then we just use the minimum spacing
            let availableWidth = collectionView.bounds.width - (flowLayout.itemSize.width / 2)
            let numberColumnsAdjusted = numberOfColumnsThatFit() - 1
            let spacingAdjusted: CGFloat = {
                if numberColumnsAdjusted == 0 {
                    return minCellHorizontalSpacing
                }
                else {
                    return (availableWidth - (CGFloat(numberColumnsAdjusted) * flowLayout.itemSize.width)) / CGFloat(numberColumnsAdjusted + 1)
                    
                }
            }()
            return spacingAdjusted
        }
    }
    
    open func verticalSpacing() -> CGFloat {
        guard let flowLayout = flowLayout() else {
            return minCellVerticalSpacing
        }
        
        if doAllCellsFit() || flowLayout.scrollDirection == .horizontal {
            // Use a spacing value that centers them vertically. First figure out how many rows we actually have
            let rawRowCount = ceilf(Float(tasks.count) / Float(numberOfColumnsThatFit()))
            let rowCount: CGFloat = {
                if tasks.count > numberOfRowsThatFit() {
                    return CGFloat([CGFloat(rawRowCount), CGFloat(numberOfRowsThatFit())].min() ?? 0)
                }
                else {
                    return CGFloat(tasks.count)
                }
            }()

            return (collectionView.bounds.height - (rowCount * flowLayout.itemSize.height)) / (rowCount + 1.0)
        }
        else {
            // We want the last visible cells on the bottom of the view to be just partially visible to inform the
            // user that they can scroll down to get more. So we take the last row that will fit and 'move it'
            // half way off screen. If only one row fits, then we just use the minimum spacing
            let availableHeight = collectionView.bounds.height - (flowLayout.itemSize.height / 2)
            let numberRowsAdjusted = numberOfRowsThatFit() - 1
            let spacingAdjusted: CGFloat = {
                if numberRowsAdjusted == 0 {
                    return minCellVerticalSpacing
                }
                else {
                    return (availableHeight - (CGFloat(numberRowsAdjusted) * flowLayout.itemSize.height)) / CGFloat(numberRowsAdjusted + 1)
                }
            }()
            return spacingAdjusted
        }
    }
}

protocol TaskBrowserTabViewDelegate {
    func taskGroupSelected(identifier: String)
}

@IBDesignable class TaskBrowserTabView: UIView {
    
    public var taskGroupIdentifier: String?
    public var delegate: TaskBrowserTabViewDelegate?
    
    @IBInspectable public var title: String? {
        didSet {
            label.text = title
        }
    }
    @IBInspectable public var isSelected: Bool = false {
        didSet {
            rule.isHidden = !isSelected
        }
    }
    
    public let rule: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = RSDDesignSystem.shared.colorRules.palette.primary.normal.color
        return view
    }()
    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 16.0)
        label.numberOfLines = 0
        label.textColor = UIColor.darkGray
        label.textAlignment = .center
        return label
    }()

    public init(frame: CGRect, taskGroupIdentifier: String) {
        super.init(frame: frame)
        self.taskGroupIdentifier = taskGroupIdentifier
        commonInit()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        
        // Add our label
        addSubview(label)
        label.rsd_alignAllToSuperview(padding: 0.0)
        
        // Add our rule
        addSubview(rule)
        rule.rsd_makeHeight(.equal, 4.0)
        rule.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: 0.0)
        
        // Add a button
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(tabSelected), for: .touchUpInside)
        addSubview(button)
        button.rsd_alignAllToSuperview(padding: 0.0)
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
        setNeedsDisplay()
    }
    
    @objc
    func tabSelected() {
        if let delegate = delegate,
            let taskGroupIdentifier = taskGroupIdentifier {
            delegate.taskGroupSelected(identifier: taskGroupIdentifier)
        }
    }
}

class TaskCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var completedCheckmark: UIImageView!
    
    public var title: String? {
        didSet {
            label.text = title
        }
    }
    public var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }
    public var isCompleted: Bool = false {
        didSet {
            completedCheckmark.isHidden = !isCompleted
        }
    }
 }

// Use this just so the corner radius show's up in Interface Builder
@IBDesignable
class RoundedCornerView: UIView {
    @IBInspectable var cornerRadius: CGFloat = 0.0 {
        didSet {
            layer.cornerRadius = cornerRadius
        }
    }
}
