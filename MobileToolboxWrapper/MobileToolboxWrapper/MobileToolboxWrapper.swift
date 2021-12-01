//
//  MobileToolboxWrapper.swift
//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
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
import MobileToolboxKit
import MSSMobileKit
import Research
import ResearchUI

public protocol MTBAssessmentViewControllerDelegate : AnyObject {
    func assessmentController(_ assessmentController: MTBAssessmentViewController, didFinishWith reason: FinishedState, error: Error?)
    func assessmentController(_ assessmentController: MTBAssessmentViewController, readyToSave result: MTBAssessmentResult)
}

public enum FinishedState : Int {
    /// Participant did not finish but wanted to save partial results.
    case saved
    /// Participant canceled the assessment without saving.
    case discarded
    /// The assessment has completed successfully.
    case completed
    /// Participant wants to skip this assessment.
    case skipped
}

public struct MTBAssessmentResult {
    public let identifier: String
    public let schemaIdentifier: String?
    public let scheduleIdentifier: String?
    public let filename: String
    public let timestamp: Date
    public let json: Data
}

var resourcesInitialized = false
func initializeResourcesIfNeeded() {
    guard !resourcesInitialized else { return }
    resourcesInitialized = true
    resourceLoader = ResourceLoader()
    LocalizationBundle.registerDefaultBundlesIfNeeded()
    AppOrientationLockUtility.defaultOrientationLock = .portrait
}

public class MTBAssessmentViewController : UIViewController {
    
    public weak var delegate: MTBAssessmentViewControllerDelegate!
    
    public let identifier: MTBIdentifier
    
    public var scheduleIdentifier : String? {
        self.taskVC.taskViewModel.scheduleIdentifier
    }
    
    public var result: MTBAssessmentResult?
    
    public init(identifier: MTBIdentifier, scheduleIdentifier: String? = nil) throws {
        initializeResourcesIfNeeded()
        let taskVendor = MSSTaskVender(taskConfigLoader: MTBStaticTaskConfigLoader.default)
        self.taskVC = try taskVendor.taskViewController(for: identifier.rawValue, scheduleIdentifier: scheduleIdentifier)
        self.identifier = identifier
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Wrapper
    
    private var taskVC: RSDTaskViewController
    private var taskDelegate: TaskViewControllerDelegate!
    
    public override var modalPresentationStyle: UIModalPresentationStyle {
        get { .fullScreen }
        set {}
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        (self.taskVC.task as? MSSAssessmentTaskObject)?.taskOrientation ?? .portrait
    }
    
    override public var prefersStatusBarHidden: Bool {
        self.taskVC.prefersStatusBarHidden
    }

    override public var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        self.taskVC.preferredScreenEdgesDeferringSystemGestures
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        taskDelegate = .init()
        taskDelegate.owner = self
        taskVC.delegate = taskDelegate
        self.addChild(taskVC)
        taskVC.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        taskVC.view.frame = self.view.bounds
        self.view.addSubview(taskVC.view)
        taskVC.didMove(toParent: self)
    }
    
    // Wrap the delegate in an object that is internal so the method isn't exposed publicly.
    private class TaskViewControllerDelegate: NSObject, RSDTaskViewControllerDelegate {
        
        weak var owner: MTBAssessmentViewController!
        
        func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
            let state: FinishedState
            if taskController.taskViewModel.didAbandon {
                state = .skipped
            }
            else {
                switch reason {
                case .saved:
                    state = .saved
                case .completed:
                    state = .completed
                default:
                    state = .discarded
                }
            }
            owner.delegate.assessmentController(owner, didFinishWith: state, error: error)
        }
        
        func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
            guard let archivable = taskViewModel.taskResult.asyncResults?.first(where: {
                $0 is RSDArchivable }) as? RSDArchivable
            else {
                assertionFailure("Failed to find an archivable result in the async results.")
                return
            }
            do {
                guard let archiveData = try archivable.buildArchiveData() else { return }
                owner.result = .init(identifier: taskViewModel.identifier,
                                     schemaIdentifier: taskViewModel.task?.schemaInfo?.schemaIdentifier,
                                     scheduleIdentifier: taskViewModel.scheduleIdentifier,
                                     filename: archiveData.manifest.filename,
                                     timestamp: archiveData.manifest.timestamp,
                                     json: archiveData.data)
                owner.delegate.assessmentController(owner, readyToSave: owner.result!)
                
            } catch {
                assertionFailure("Failed to archive result: \(error).")
            }
        }
    }
}

public enum MTBIdentifier : String, CaseIterable {
    case numberMatch = "Number Match"
    case mfs = "MFS pilot 2"
    case dccs = "Dimensional Change Card Sort"
    case fnamea = "FNAME Learning Form 1"
    case flanker = "Flanker Inhibitory Control"
    case fnameb = "FNAME Test Form 1"
    case psm = "Picture Sequence MemoryV1"
    case spelling = "MTB Spelling Form 1"
    case vocabulary = "Vocabulary Form 1"
}

