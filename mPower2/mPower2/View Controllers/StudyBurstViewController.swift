//
//  StudyBurstViewController.swift
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
import ResearchUI

class StudyBurstViewController: UIViewController {
    
    private let kTaskBrowserSegueIdentifier = "StudyBurstTaskBrowserSegue"

    @IBOutlet weak var headerView: RSDTableStepHeaderView!
    @IBOutlet weak var progressContainerView: UIView!
    @IBOutlet weak var progressCircleView: ProgressCircleView!
    @IBOutlet weak var navFooterView: RSDGenericNavigationFooterView!
    @IBOutlet weak var progressLabel: StudyBurstProgressExpirationLabel!
    
    var scheduleManager: StudyBurstScheduleManager?
    var taskBrowserVC: StudyBurstTaskBrowserViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    func setupView() {
        // Setup our back button
        headerView.cancelButton?.setImage(UIImage(named: "BackButtonIcon"), for: .normal)
        headerView.cancelButton?.addTarget(self, action: #selector(backHit(sender:)), for: .touchUpInside)
        
        // Setup our next button
        navFooterView.nextButton?.addTarget(self, action: #selector(nextHit(sender:)), for: .touchUpInside)
        
        // Update progress circle
        progressCircleView.progress = scheduleManager?.progress ?? 0.0
        progressCircleView.displayDay(count: scheduleManager?.dayCount ?? 0)
        
        // Update progress view
        headerView.progressView?.totalSteps = scheduleManager?.numberOfDays ?? 0
        headerView.progressView?.currentStep = scheduleManager?.dayCount ?? 0
        
        // Update greeting and message
        // TODO: jbruhin 5-31-18 implement using document and rules provided in Jira ticket

        // Set ourselves as delegate on our progress label so we can provide progress expiry date
        progressLabel.delegate = self
        if let expiresOn = scheduleManager?.expiresOn {
            progressLabel.updateStudyBurstExpirationTime(expiresOn)
        }
        
        // TODO: jbruhin 5-31-18 I think we're supposed to hide the progress label in certain
        // circumstances. Need to look into that.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kTaskBrowserSegueIdentifier,
            let taskBrowser = segue.destination as? StudyBurstTaskBrowserViewController {
            if let scheduleManager = scheduleManager {
                taskBrowser.scheduleManagers = [scheduleManager]
            }
            taskBrowser.delegate = self
            taskBrowserVC = taskBrowser
        }
    }
    
    static func instantiate() -> StudyBurstViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "StudyBurstViewController") as? StudyBurstViewController
    }
    
    // MARK: Actions
    @objc func backHit(sender: Any) {
        if let nc = self.navigationController {
            nc.popViewController(animated: true)
        }
    }
    @objc func nextHit(sender: Any) {
        taskBrowserVC?.startNextTask()
    }
}

extension StudyBurstViewController: StudyBurstProgressExpirationLabelDelegate {
    func studyBurstExpiresOn() -> Date? {
        return scheduleManager?.expiresOn
    }
}

extension StudyBurstViewController: TaskBrowserViewControllerDelegate {
    
    // MARK: TaskBrowserViewControllerDelegate
    func taskBrowserToggleVisibility() {
        // Nothing
    }
    func taskBrowserTabSelected() {
        // Nothing
    }
}

class StudyBurstTaskBrowserViewController: TaskBrowserViewController {
    
    // TODO: jbruhin 5-31-18 find better way to define number of columns, should be based on available space
    // even though the design seems to prescribes two columns
    private let kNumberOfColumns = 2
    
    func firstIncompleteTaskId() -> String? {
        guard let  scheduleManager = scheduleManagers?.first else {
            return nil
        }
        let task = tasks.first(where: { (taskInfo) -> Bool in
            !scheduleManager.isCompleted(for: taskInfo, on: Date())
        })
        return task?.identifier
    }
    
    // MARK: Instance methods
    public func startNextTask() {
        // Get the next incomplete task and present it.
        if let taskInfo = tasks.first(where: { $0.identifier == firstIncompleteTaskId() }) {
            startTask(for: taskInfo)
        }
    }
    
    // MARK: Overrides
    override var tasks: [RSDTaskInfo] {
        guard let studyBurstManager = scheduleManagers?.first as? StudyBurstScheduleManager else {
            return [RSDTaskInfo]()
        }
        return studyBurstManager.orderedTasks()
    }
    override var collectionCellIdentifier: String {
        return "StudyBurstCollectionViewCell"
    }
    override var shouldShowTabs: Bool {
        return false
    }
    override var shouldShowTopShadow: Bool {
        return false
    }
    override func horizontalSpacing(for collectionView: UICollectionView, layout: UICollectionViewLayout) -> CGFloat {
        
        guard let flowLayout = layout as? UICollectionViewFlowLayout else {
            return kMinCellHorizontalSpacing
        }
        
        // Center the cells horizontally and distribute them evenly
        let cellCount = [kNumberOfColumns, tasks.count].min() ?? 0
        return (collectionView.bounds.width - (CGFloat(cellCount) * flowLayout.itemSize.width)) / (CGFloat(cellCount) + 1.0)
    }
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        // TODO: jbruhin 5-31-18 optimize vertical layout for all screen sizes
        return 20.0
    }

    // MARK: UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collectionCellIdentifier, for: indexPath) as? StudyBurstCollectionViewCell
        let task = tasks[indexPath.row]
        
        cell?.title = task.title
        cell?.image = nil
        if let scheduleManager = scheduleManagers?.first {
            
            let isCompleted = scheduleManager.isCompleted(for: task, on: Date())
            cell?.isCompleted = isCompleted
            task.imageVendor?.fetchImage(for: collectionView.layoutAttributesForItem(at: indexPath)?.size ?? .zero) { (_, img) in
                
                // If the task is completed or is the first incomplete task, we show the image as normal,
                // otherwise we show a grayscale version of the image
                cell?.image = isCompleted || task.identifier == self.firstIncompleteTaskId() ? img : img?.grayscale()
            }
            
            // If the task is completed or is the first incomplete task, we change the alpha of the cell to normal (1.0),
            // otherwise we dim the view by changing the alpha to less than 1.0
            cell?.alpha = isCompleted || task.identifier == self.firstIncompleteTaskId() ? 1.0 : 0.5
        }
        
        // TODO: jbruin 5-31-18 update this label with actual data, not sure yet where it comes from
        cell?.durationLabel.text = "2 minutes"
        
        return cell ?? UICollectionViewCell()
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Only launch the task if this is the first availble (ie. not completed) task
        if tasks[indexPath.row].identifier == self.firstIncompleteTaskId() {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }
}

class StudyBurstCollectionViewCell: TaskCollectionViewCell {
    @IBOutlet weak var durationLabel: UILabel!
    public var durationString: String? {
        didSet {
            durationLabel.text = durationString
        }
    }
}

extension UIImage {
    func grayscale() -> UIImage {
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIPhotoEffectTonal")
        currentFilter!.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        let cgimg = context.createCGImage(output!, from: output!.extent)
        let processedImage = UIImage(cgImage: cgimg!, scale: scale, orientation: imageOrientation)
        return processedImage
    }
}

