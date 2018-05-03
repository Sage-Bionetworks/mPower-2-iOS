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

protocol TaskBrowserViewControllerDelegate {
    func taskBrowserViewControllerToggleVisibility()
}

class TaskBrowserViewController: UIViewController, RSDTaskViewControllerDelegate, TaskBrowserTabViewDelegate {
    
    // Used by our potential parent VC to show/hide our view
    class func tabsHeight() -> CGFloat {
        return 50.0
    }
    
    private let kCollectionCellIdentifier = "TaskCollectionViewCell"
    private let kTopInset: CGFloat = 30.0

    // TODO: jbruhin 5-1-18 need to optimize for all screen sizes
    open var cellSize = CGSize(width: 80.0, height: 80.0)
    open var minCellSpacing: CGFloat = 30.0
    
    public var shouldShowTopShadow = true
    public var taskGroups: [RSDTaskGroup]?

    private var collectionView: UICollectionView!
    private var tabButtonStackView: UIStackView!
    private var selectedTaskGroup: RSDTaskGroup?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // temp
        taskGroups = {
            let activeTaskGroup : RSDTaskGroup = {
                let taskInfos = MCTTaskIdentifier.all().map { MCTTaskInfo($0) }
                var taskGroup = RSDTaskGroupObject(with: "Measuring", tasks: taskInfos)
                taskGroup.title = "Measuring"
                return taskGroup
            }()
            let trackingTaskGroup : RSDTaskGroup = {
                var taskInfo = RSDTaskInfoObject(with: "Triggers")
                taskInfo.title = "Triggers"
                if let image = try? RSDImageWrapper(imageName: "TriggerIcon-oval") {
                    taskInfo.icon = image
                }
                taskInfo.resourceTransformer = RSDResourceTransformerObject(resourceName: "Triggers")
                var taskGroup = RSDTaskGroupObject(with: "Tracking", tasks: [taskInfo])
                taskGroup.title = "Tracking"
                return taskGroup
            }()
            
            return [trackingTaskGroup, activeTaskGroup]
        }()

        
        setupView()
    }
    
    func shouldShowTabs() -> Bool {
        guard let taskGroups = taskGroups else {
            return false
        }
        return taskGroups.count > 1
    }
    
    func setupView() {
        
        // Let's select the first task group by default.
        selectedTaskGroup = taskGroups?.first
        
        tabButtonStackView = UIStackView(frame: .zero)
        tabButtonStackView.translatesAutoresizingMaskIntoConstraints = false
        tabButtonStackView.axis = .horizontal
        tabButtonStackView.distribution = .fillEqually
        view.addSubview(tabButtonStackView)
        
        // Pin left, right, top to superview
        tabButtonStackView.rsd_alignToSuperview([.leading, .top, .trailing], padding: 0.0)

        // If we have more than one TaskGroup, we create tabs for each group. If we don't, we do not
        // create tabs and we set the height of the tabButtonStackView to 0, essentially hiding it
        if shouldShowTabs(),
            let taskGroups = taskGroups {
            
            taskGroups.forEach({
                let tabView = TaskBrowserTabView(frame: .zero, taskGroupIdentifier: $0.identifier)
                tabView.title = $0.title
                tabView.delegate = self
                if let selectedTaskGroup = self.selectedTaskGroup {
                    tabView.isSelected = ($0.identifier == selectedTaskGroup.identifier)
                }
                tabButtonStackView.addArrangedSubview(tabView)
            })
            
            // set the tabView height
            tabButtonStackView.rsd_makeHeight(.equal, TaskBrowserViewController.tabsHeight())
        }
        else {
            tabButtonStackView.rsd_makeHeight(.equal, 0.0)
        }

        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = cellSize
        layout.minimumInteritemSpacing = minCellSpacing

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = UIColor.white

        view.addSubview(collectionView)
        
        // Pin below stackView and left, right and bottom to superview
        collectionView.rsd_alignBelow(view: tabButtonStackView, padding: 0.0)
        collectionView.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: 0.0)
        
        // Register our cells for reuse
        collectionView.register(TaskCollectionViewCell.self, forCellWithReuseIdentifier: kCollectionCellIdentifier)
        
        collectionView.reloadData()
        
        if shouldShowTabs() {
            // We also add a 1px tall rule underneath the tabBar
            let rule = UIView()
            rule.translatesAutoresizingMaskIntoConstraints = false
            rule.backgroundColor = UIColor.royal200
            view.addSubview(rule)
            rule.rsd_alignBelow(view: tabButtonStackView, padding: 0.0)
            rule.rsd_alignToSuperview([.leading, .trailing], padding: 0.0)
            rule.rsd_makeHeight(.equal, 1.0)
        }
        
        // Finally, add a shadow if required
        if shouldShowTopShadow {
            let shadow = RSDShadowGradient()
            shadow.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(shadow)
            shadow.rsd_makeHeight(.equal, 5.0)
            shadow.rsd_alignToSuperview([.leading, .trailing], padding: 0.0)
            shadow.rsd_alignToSuperview([.top], padding: -5.0)
        }
    }
    
    // MARK: RSDTaskViewControllerDelegate
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        // dismiss the view controller
        (taskController as? UIViewController)?.dismiss(animated: true) {
        }
        
        print("\n\n=== Completed: \(reason) error:\(String(describing: error))")
        print(taskController.taskPath.result)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        //
    }
    
    func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
    }

    // MARK: TaskBrowserTabViewDelegate
    func taskGroupSelected(identifier: String) {
        
        // Save our selected task group and reload collection
        selectedTaskGroup = taskGroups?.filter({ $0.identifier == identifier }).first
        collectionView.reloadData()
        
        // Now update the isSelected value of all the tabs
        tabButtonStackView.arrangedSubviews.forEach({
            if let tabView = $0 as? TaskBrowserTabView {
                tabView.isSelected = tabView.taskGroupIdentifier == identifier
            }
        })
    }
}

extension TaskBrowserViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let selectedTaskGroup = selectedTaskGroup else {
            return 0
        }
        return selectedTaskGroup.tasks.count
    }
    
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kCollectionCellIdentifier, for: indexPath) as? TaskCollectionViewCell
        if let selectedTaskGroup = selectedTaskGroup {
            
            let task = selectedTaskGroup.tasks[indexPath.row]
            cell?.image = nil
            task.imageVendor?.fetchImage(for: CGSize(width: 0.0, height: 0.0)) { (_, img) in
                cell?.image = img
            }
            cell?.title = task.title?.uppercased()
        }
        return cell ?? UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let selectedTaskGroup = selectedTaskGroup else {
            return
        }

        // Get our task and present it
        let taskInfo = selectedTaskGroup.tasks[indexPath.row]
        guard let taskPath = selectedTaskGroup.instantiateTaskPath(for: taskInfo) else { return }
        let vc = RSDTaskViewController(taskPath: taskPath)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        guard let selectedTaskGroup = selectedTaskGroup else {
            return UIEdgeInsetsMake(0, 0, 0, 0)
        }
        
        // We do this so the cells are centered horizontally

        let totalCellWidth = cellSize.width * CGFloat(selectedTaskGroup.tasks.count)
        let totalSpacingWidth = minCellSpacing * (CGFloat(selectedTaskGroup.tasks.count) - 1)
        let inset = (collectionView.frame.size.width - CGFloat(totalCellWidth + totalSpacingWidth)) / 2

        return UIEdgeInsetsMake(kTopInset, inset, 0, inset)
    }
}

protocol TaskBrowserTabViewDelegate {
    func taskGroupSelected(identifier: String)
}

class TaskBrowserTabView: UIView {
    
    public var taskGroupIdentifier: String?
    public var delegate: TaskBrowserTabViewDelegate?
    
    public var title: String? {
        didSet {
            label.text = title
        }
    }
    public var isSelected: Bool = false {
        didSet {
            rule.isHidden = !isSelected
        }
    }
    
    private let rule: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.royal500
        return view
    }()
    private let label: UILabel = {
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
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @objc func tabSelected() {
        if let delegate = delegate,
            let taskGroupIdentifier = taskGroupIdentifier {
            delegate.taskGroupSelected(identifier: taskGroupIdentifier)
        }
    }
}

class TaskCollectionViewCell: UICollectionViewCell {
    
    private let kVerticalPadding: CGFloat = 5.0

    private var imageView: UIImageView?
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 12.0)
        label.numberOfLines = 0
        label.textColor = UIColor.darkGray
        label.textAlignment = .center
        return label
    }()
    
    public var title: String? {
        didSet {
            label.text = title
        }
    }
    public var image: UIImage? {
        didSet {
            setNeedsLayout()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // We want to size and constrain the imageView based on the size of the image,
        // rather than choosing how to scale the image to fit the view. So we always
        // remove all the subviews, recreate the imageView with the current image,
        // re-add and layout the imageView and the label
        
        contentView.subviews.forEach({ $0.removeFromSuperview() })
        
        // Add our imageView. Pin to the top, center horizontally and fix its size
        imageView = UIImageView(image: image)
        imageView?.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView!)
        imageView?.rsd_alignToSuperview([.top], padding: 0.0)
        imageView?.rsd_alignCenterHorizontal(padding: 0.0)
        
        // Add our label and position under imageView, pin left and right to superview
        contentView.addSubview(label)
        label.rsd_alignBelow(view: imageView!, padding: kVerticalPadding)
        label.rsd_alignToSuperview([.leading, .trailing], padding: 0.0)
    }
}
