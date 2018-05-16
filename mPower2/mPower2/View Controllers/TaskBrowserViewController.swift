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
    
    // Used by our potential parent VC to show/hide our collectionView
    class func tabsHeight() -> CGFloat {
        return 50.0
    }
    
    private let kCollectionCellIdentifier = "TaskCollectionViewCell"
    private let kMinCellHorizontalSpacing: CGFloat = 5.0

    public var shouldShowTopShadow = true
    public var taskGroups: [RSDTaskGroup]?

    private var selectedTaskGroup: RSDTaskGroup?
    
    @IBOutlet weak var tabButtonStackView: UIStackView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var ruleView: UIView!
    @IBOutlet weak var shadowView: RSDShadowGradient!
    @IBOutlet weak var tabsViewHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    func shouldShowTabs() -> Bool {
        guard let taskGroups = taskGroups else {
            return false
        }
        return taskGroups.count > 1
    }
    
    func setupView() {
        
        // Remove existing managed subviews from tabBar stackView
        tabButtonStackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        // Let's select the first task group by default.
        selectedTaskGroup = taskGroups?.first
        
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
            tabsViewHeightConstraint.constant = TaskBrowserViewController.tabsHeight()
        }
        else {
            tabsViewHeightConstraint.constant = 0.0
        }
        
        // Hide or show our shadow and rule views
        shadowView.isHidden = !shouldShowTopShadow
        ruleView.isHidden = !shouldShowTabs()

        // Reload our data
        collectionView.reloadData()
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
            task.imageVendor?.fetchImage(for: collectionView.layoutAttributesForItem(at: indexPath)?.size ?? .zero) { (_, img) in
                cell?.image = img
            }
            cell?.title = task.title?.uppercased()
        }
        return cell ?? UICollectionViewCell()
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
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellItemSpacing(for: collectionView, layout: collectionViewLayout)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
                return collectionView.contentInset
        }

        let spacing = cellItemSpacing(for: collectionView, layout: collectionViewLayout)
        return UIEdgeInsetsMake(flowLayout.sectionInset.top, spacing, flowLayout.sectionInset.bottom, spacing)
    }
    
    func cellItemSpacing(for collectionView: UICollectionView, layout: UICollectionViewLayout) -> CGFloat {
        guard let selectedTaskGroup = selectedTaskGroup,
            let flowLayout = layout as? UICollectionViewFlowLayout else {
                return kMinCellHorizontalSpacing
        }
        
        // We want our cells to be laid out in one horizontal row, with scrolling if necessary.
        // The default layout behavior for UICollectionView is to layout the cells from left to right.
        // In our case, we may want the cells centered horizontally in the view, which means we must
        // calculate the desired spacing so the cells appear centered. However, we may have more cells
        // than can fit in the collectionView.bounds, in which case we want the cells laid out from
        // left to right and extending beyond the bounds of the collectionView, then the user can scroll
        // horizontally as needed. In this case, we want the last visible cell on the right side of the
        // view to be just partially visible - ie. half on screen, half off screen - to inform the user
        // that they can scroll to the right to get more.
        
        let totalCellWidth = flowLayout.itemSize.width * CGFloat(selectedTaskGroup.tasks.count)
        let totalSpacingWidth = kMinCellHorizontalSpacing * (CGFloat(selectedTaskGroup.tasks.count) + 1)
        let totalWidth = totalCellWidth + totalSpacingWidth
        
        if totalWidth > collectionView.bounds.width {
            // Find a spacing value that results in the last visible cell being positioned half off-screen
            let availableWidth = collectionView.bounds.width - (flowLayout.itemSize.width / 2)
            let qtyCellsThatFit = floorf(Float(availableWidth / (flowLayout.itemSize.width + kMinCellHorizontalSpacing)))
            let spacingAdjusted = (availableWidth - (CGFloat(qtyCellsThatFit) * flowLayout.itemSize.width)) / CGFloat(qtyCellsThatFit + 1)
            return spacingAdjusted
        }
        else {
            // All cells will fit, so use a spacing value that centers them horizontally
            let cellCount = CGFloat(selectedTaskGroup.tasks.count)
            return (collectionView.bounds.width - (cellCount * flowLayout.itemSize.width)) / (cellCount + 1.0)
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
    
    let rule: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.royal500
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
    
    @objc func tabSelected() {
        if let delegate = delegate,
            let taskGroupIdentifier = taskGroupIdentifier {
            delegate.taskGroupSelected(identifier: taskGroupIdentifier)
        }
    }
}

class TaskCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
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
