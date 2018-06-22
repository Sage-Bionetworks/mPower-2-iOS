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

extension RSDIdentifier {
    static let studyBurstCompletionStep: RSDIdentifier = "studyBurstCompletion"
}

class StudyBurstViewController: UIViewController {
    
    private let kProgressContainerViewHeight = CGFloat(80.0).rsd_proportionalToScreenHeight()
    private let kTaskBrowserSegueIdentifier = "StudyBurstTaskBrowserSegue"
    private let kHasSeenCompletionKey = "HasSeenStudyBurstCompletion"

    @IBOutlet weak var headerView: RSDTableStepHeaderView!
    @IBOutlet weak var progressContainerView: UIView!
    @IBOutlet weak var progressCircleView: ProgressCircleView!
    @IBOutlet weak var navFooterView: RSDGenericNavigationFooterView!
    @IBOutlet weak var progressLabel: StudyBurstProgressExpirationLabel!
    @IBOutlet weak var progressContainerViewHeightConstraint: NSLayoutConstraint!
    
    var taskBrowserVC: StudyBurstTaskBrowserViewController?
    
    var studyBurstManager: StudyBurstScheduleManager!
    
    var shouldShowCompletionView: Bool {
        return studyBurstManager?.isCompletedForToday ?? false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    func setupView() {
        
        guard let studyBurstManager = studyBurstManager else {
            return
        }
        
        // Setup our back button
        headerView.cancelButton?.setImage(UIImage(named: "BackButtonIcon"), for: .normal)
        headerView.cancelButton?.addTarget(self, action: #selector(backHit(sender:)), for: .touchUpInside)
        
        // Setup our next button
        navFooterView.nextButton?.addTarget(self, action: #selector(nextHit(sender:)), for: .touchUpInside)
        
        // Update progress circle
        progressCircleView.progress = studyBurstManager.progress
        progressCircleView.displayDay(count: studyBurstManager.dayCount ?? 0)
        
        // Update progress view
        headerView.progressView?.totalSteps = studyBurstManager.numberOfDays
        headerView.progressView?.currentStep = studyBurstManager.dayCount ?? 0
        
        // Update greeting and message
        let content = welcomeContent()
        headerView.titleLabel?.text = content.title
        headerView.textLabel?.text = content.message
        
        // Set ourselves as delegate on our progress label so we can provide progress expiry date
        progressLabel.delegate = self
        if let expiresOn = studyBurstManager.expiresOn {
            progressLabel.updateStudyBurstExpirationTime(expiresOn)
        }
        
        // Set the height of the progress container view
        progressContainerViewHeightConstraint.constant = kProgressContainerViewHeight
    }
    
    func welcomeContent() -> (title: String?, message: String?) {
        
        guard let studyBurstManager = studyBurstManager else {
            return ("", "")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        let currentDaysStr = formatter.string(for: studyBurstManager.dayCount)!
        
        // The title string is the same regardless of how many days they've missed, if any.
        // It will vary only by the current day of the study burst
        let formatStr = String(format: "STUDY_BURST_TITLE_DAY_%@", currentDaysStr)
        let titleStr = Localization.localizedString(formatStr)
        
        let messageStr: String? = {
            if studyBurstManager.missedDaysCount == 0 {
                // The message will vary by the current day of the study burst
                let format = String(format: "STUDY_BURST_MESSAGE_DAY_%@", currentDaysStr)
                return Localization.localizedString(format)
            }
            else {
                // The message will be the same for each day of the study burst and will simply
                // indicate the current day and the number of missed days
                let missedDaysStr = formatter.string(for: studyBurstManager.missedDaysCount)!
                
                let format = studyBurstManager.missedDaysCount > 1 ?
                    Localization.localizedString("STUDY_BURST_MESSAGE_IN_%@_DAYS_MISSED_%@_DAYS") :
                    Localization.localizedString("STUDY_BURST_MESSAGE_IN_%@_DAYS_MISSED_ONE_DAY")
                
                let str = studyBurstManager.missedDaysCount > 1 ?
                    String.localizedStringWithFormat(format, currentDaysStr, missedDaysStr) :
                    String.localizedStringWithFormat(format, currentDaysStr)
                
                return str
            }
        }()
        
        return (titleStr, messageStr)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kTaskBrowserSegueIdentifier,
            let taskBrowser = segue.destination as? StudyBurstTaskBrowserViewController,
            let studyBurstManager = studyBurstManager {
            
            taskBrowser.scheduleManagers = [studyBurstManager]
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
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @objc func nextHit(sender: Any) {
        // If user is completed for today, then show the Completion VC, otherwise, show the next task
        if studyBurstManager?.isCompletedForToday ?? false {
            self.navigationController?.popToRootViewController(animated: true)
        }
        else {
            taskBrowserVC?.startNextTask()
        }
    }
    
    func showCompletionView() {
        // TODO: syoung 06/20/2018 Update title/text to "congradulations" with party sprinkles.
        self.navFooterView.nextButton?.setTitle(Localization.buttonDone(), for: .normal)
        
        // If there is a task to do today, then push it.
        if let taskPath = studyBurstManager.completionTaskPath() {
            let vc = RSDTaskViewController(taskPath: taskPath)
            vc.delegate = self
            self.navigationController!.pushViewController(vc, animated: false)
        }
    }
}

extension StudyBurstViewController: RSDTaskViewControllerDelegate {
    
    open func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        // dismiss the view controller
        if let vc = taskController as? UIViewController {
            if vc == self.navigationController?.topViewController {
                self.navigationController?.popToRootViewController(animated: true)
            }
            else {
                vc.dismiss(animated: true) {
                    self.navigationController?.popToRootViewController(animated: false)
                }
            }
        }
        // Let the schedule manager handle the cleanup.
        studyBurstManager.taskController(taskController, didFinishWith: reason, error: error)
    }

    func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        studyBurstManager.taskController(taskController, readyToSave: taskPath)
    }

    func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return studyBurstManager.taskController(taskController, asyncActionControllerFor:configuration)
    }
    
    func taskViewController(_ taskViewController: UIViewController, viewControllerFor step: Any) -> UIViewController? {
        guard let step = step as? RSDStep, step.identifier == RSDIdentifier.studyBurstCompletionStep
            else {
                return nil
        }
        let vc = StudyBurstCompletionViewController.instantiate()
        vc?.step = step
        return vc
    }
}

extension StudyBurstViewController: StudyBurstProgressExpirationLabelDelegate {
    func studyBurstExpiresOn() -> Date? {
        return studyBurstManager?.expiresOn
    }
}

extension StudyBurstViewController: TaskBrowserViewControllerDelegate {
    
    func taskBrowserDidFinish(task: RSDTaskPath, reason: RSDTaskFinishReason) {
        if reason == .completed, studyBurstManager.isFinalTask(task) {
            showCompletionView()
        }
    }
    
    // MARK: TaskBrowserViewControllerDelegate
    func taskBrowserToggleVisibility() {
        // Nothing
    }
    func taskBrowserTabSelected() {
        // Nothing
    }
    func taskBrowserDidLayoutSubviews() {
        // After the task browser has been layed out, check to see if we should show the shadow on our nav footer view
        guard let taskBrowserVC = taskBrowserVC else {
            return
        }
        
        // Test current visible state of shadow before setting it to avoid multiple calls to set the property
        let shouldShowShadow = taskBrowserVC.collectionView.collectionViewLayout.collectionViewContentSize.height > taskBrowserVC.collectionView.bounds.height
        if shouldShowShadow != navFooterView.shouldShowShadow {
            navFooterView.shouldShowShadow = shouldShowShadow
        }
    }
}

class StudyBurstTaskBrowserViewController: TaskBrowserViewController {
    
    func firstIncompleteTaskId() -> String? {
        guard let scheduleManager = scheduleManagers?.first else {
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
    override var minCellHorizontalSpacing: CGFloat {
        return 30.0
    }
    
    override var minCellVerticalSpacing: CGFloat {
        return 10.0
    }
    
    override var tasks: [RSDTaskInfo] {
        guard let studyBurstManager = scheduleManagers?.first as? StudyBurstScheduleManager else {
            return [RSDTaskInfo]()
        }
        return studyBurstManager.orderedTasks
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
        
        // Update the estimated minutes label
        cell?.durationLabel.text = Localization.localizedStringWithFormatKey("%@_ESTIMATED_MINUTES", NSNumber(value: task.estimatedMinutes))

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

