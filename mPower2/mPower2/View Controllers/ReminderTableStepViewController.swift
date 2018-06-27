//
//  ReminderTableStepViewController.swift
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

class ReminderTableStepViewController: RSDTableStepViewController {
    
    override func registerReuseIdentifierIfNeeded(_ reuseIdentifier: String) {

        // We want to use the custom 'ReminderTextFieldCell' text field cell for the .picker type
        if let _ = RSDTableItem.ReuseIdentifier(rawValue: reuseIdentifier) {
            super.registerReuseIdentifierIfNeeded(reuseIdentifier)
        }
        else {
            let reuseId = RSDFormUIHint(rawValue: reuseIdentifier)
            switch reuseId {
            case .picker:
                let cellClass: AnyClass = ReminderTextFieldCell.self
                tableView.register(cellClass, forCellReuseIdentifier: reuseIdentifier)
            default:
                super.registerReuseIdentifierIfNeeded(reuseIdentifier)
            }
        }
    }

    override func configure(cell: UITableViewCell, in tableView: UITableView, at indexPath: IndexPath) {
        
        super.configure(cell: cell, in: tableView, at: indexPath)
        
        // We don't want to show a label above the text field
        if let textFieldCell = cell as? RSDStepTextFieldCell {
            textFieldCell.fieldLabel.text = nil
        }
    }
    
    override func setupModel() {
        
        super.setupModel()
        
        // We want a section label above the time picker cell, which doesn't have one by default.
        // So we set the title of that table item
        (tableData?.sections.first)?.title = "Set Reminder"
        
        // We don't want a section label above the checkbox, so we nil the title of that table item
        (tableData?.sections.last)?.title = nil
    }
}


class ReminderTextFieldCell: RSDStepTextFieldCell {
    
    open var topRuleView: UIView!

    override func initializeViews() {
        super.initializeViews()
        
        // Add an additional rule
        topRuleView = UIView()
        topRuleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(topRuleView)
    }
    
    override var usesLightStyle: Bool {
        didSet {
            if !usesLightStyle {
                topRuleView.backgroundColor = UIColor.appVeryLightGray
                ruleView.backgroundColor = UIColor.appVeryLightGray
            }
        }
    }

    override open func updateConstraints() {
        
        super.updateConstraints()
        NSLayoutConstraint.deactivate(self.constraints)
        
        textField.rsd_removeSiblingAndAncestorConstraints()
        ruleView.rsd_removeSiblingAndAncestorConstraints()
        topRuleView.rsd_removeSiblingAndAncestorConstraints()

        ruleView.rsd_makeHeight(.equal, 1.0)
        topRuleView.rsd_makeHeight(.equal, 1.0)
        
        topRuleView.rsd_alignToSuperview([.top, .leading, .trailing], padding: 0.0)

        textField.rsd_alignToSuperview([.leading, .trailing], padding: constants.sideMargin)
        textField.rsd_alignBelow(view: topRuleView, padding: 25.0)

        ruleView.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: 0.0)
        ruleView.rsd_alignBelow(view: textField, padding: 25.0)
        
    }
}
