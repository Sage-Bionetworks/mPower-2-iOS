//
//  PassiveDataPermissionStepViewController.swift
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

import BridgeApp

extension UILabel {
    /// Convenience method for setting a nav header label's layout constraints.
    open func setConstraints(in navHeader: RSDStepHeaderView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.numberOfLines = 0
        self.textAlignment = .center
        self.preferredMaxLayoutWidth = navHeader.constants.labelMaxLayoutWidth
        
        self.rsd_alignToSuperview([.leading, .trailing], padding: navHeader.constants.sideMargin)
        self.rsd_makeHeight(.greaterThanOrEqual, 0.0)
    }
}

class PassiveDataPermissionStepViewController: RSDTableStepViewController {
    let permissionResultIdentifier = RSDIdentifier.passiveDataPermissionProfileKey

    static func instantiate(with step: RSDStep, parent: RSDPathComponent?) -> PassiveDataPermissionStepViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "PassiveDataPermissionStepViewController") as? PassiveDataPermissionStepViewController
        vc?.stepViewModel = vc?.instantiateStepViewModel(for: step, with: parent)
        return vc
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        guard let navHeader = self.navigationHeader as? RSDTableStepHeaderView else { return }
        navHeader.removeFromSuperview()
        self.tableView.tableHeaderView = navHeader
        
        navHeader.titleLabel?.setConstraints(in: navHeader)
        navHeader.textLabel?.setConstraints(in: navHeader)
    }
    
    override open func setupStatusBar(with background: RSDColorTile) {
        let designSystem = RSDDesignSystem()
        super.setupStatusBar(with: designSystem.colorRules.backgroundPrimary)
    }
    
    override func goForward() {
        guard validateAndSave()
            else {
                return
        }
        
        guard let taskResult = self.stepViewModel?.taskResult,
                let step = self.stepViewModel?.step as? PassiveDataPermissionStepObject,
                let gavePermission = taskResult.findAnswerResult(with: step.identifier)?.value as? Bool
            else {
                return
        }
        
        let pm = SBAProfileManagerObject.shared
        do {
            try pm.setValue(gavePermission, forProfileKey: RSDIdentifier.passiveDataPermissionProfileKey.rawValue)
        } catch let err {
            print("Error attempting to set profile item with key \(RSDIdentifier.passiveDataPermissionProfileKey.rawValue) to \(gavePermission): \(err)")
            return
        }

        // Give the profile-item-value-updated notification a chance to be processed before going forward
        DispatchQueue.main.async {
            super.goForward()
        }
    }
}
