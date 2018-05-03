//
//  TaskBrowserViewController.swift
//  mPower2
//
//  Created by Josh Bruhin on 5/1/18.
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//

import UIKit
import Research
import MotorControl

class TaskBrowserViewController: UIViewController, RSDTaskViewControllerDelegate {
    
    private let kTabsHeight = 56.0
    
    public var shouldShowTopShadow = true
    
    var collectionView: UICollectionView!
    var tabButtonStackView: UIStackView!
    
    var taskGroups: [RSDTaskGroup]?
    
    var selectedTaskGroup: RSDTaskGroup?
    
    
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func cellSize() -> CGSize {
        return CGSize(width: 80.0, height: 80.0)
    }
    
    func minCellSpacing() -> CGFloat {
        return 30.0
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
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        tabButtonStackView = UIStackView(frame: .zero)
        tabButtonStackView.translatesAutoresizingMaskIntoConstraints = false
        tabButtonStackView.axis = .horizontal
        tabButtonStackView.distribution = .fillEqually
        view.addSubview(tabButtonStackView)
        
        // Pin left, right, top and set our height
        tabButtonStackView.rsd_alignToSuperview([.leading, .top, .trailing], padding: 0.0)

        // If we have more than one TaskGroup, we create tabs for each group. If we don't, we do not
        // create tabs and we set the height of the tabButtonStackView to 0, essentially hiding it
        if shouldShowTabs(),
            let taskGroups = taskGroups {
            
            taskGroups.forEach({
                let tabView = TaskBrowserTabView(frame: .zero)
                tabView.title = $0.title
                if let selectedTaskGroup = self.selectedTaskGroup {
                    tabView.isSelected = ($0.identifier == selectedTaskGroup.identifier)
                }
                tabButtonStackView.addArrangedSubview(tabView)
            })
            tabButtonStackView.rsd_makeHeight(.equal, 50.0)
        }
        else {
            tabButtonStackView.rsd_makeHeight(.equal, 0.0)
        }

        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
        layout.itemSize = cellSize()
        layout.minimumInteritemSpacing = minCellSpacing()
//        layout.minimumLineSpacing = 0.0

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
        collectionView.register(TaskCollectionViewCell.self, forCellWithReuseIdentifier: "TaskCollectionViewCell")
        
        collectionView.reloadData()
        
        if shouldShowTabs() {
            // We also add a 1px tall rule underneath the tabBar
            let rule = UIView()
            rule.translatesAutoresizingMaskIntoConstraints = false
            rule.backgroundColor = UIColor.lightGray
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TaskCollectionViewCell", for: indexPath) as? TaskCollectionViewCell
        if let selectedTaskGroup = selectedTaskGroup {
            let task = selectedTaskGroup.tasks[indexPath.row]
            task.imageVendor?.fetchImage(for: CGSize(width: 0.0, height: 0.0)) { (_, img) in
                cell?.image = img
            }
            cell?.title = task.title?.uppercased()
        }
        return cell ?? UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize()
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

        let totalCellWidth = cellSize().width * CGFloat(selectedTaskGroup.tasks.count)
        let totalSpacingWidth = minCellSpacing() * (CGFloat(selectedTaskGroup.tasks.count) - 1)

        let leftInset = (collectionView.frame.size.width - CGFloat(totalCellWidth + totalSpacingWidth)) / 2
        let rightInset = leftInset

        return UIEdgeInsetsMake(30, leftInset, 0, rightInset)
    }
    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//        return 0.0
//    }
}

class TaskBrowserTabView: UIView {
    
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
        view.backgroundColor = UIColor.purple
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

    override public init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.rsd_alignAllToSuperview(padding: 0.0)
        
        addSubview(rule)
        rule.rsd_makeHeight(.equal, 4.0)
        rule.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: 0.0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

class TaskCollectionViewCell: UICollectionViewCell {
    
    private let kVerticalPadding: CGFloat = 5.0

    private var imageView: UIImageView?
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 16.0)
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
