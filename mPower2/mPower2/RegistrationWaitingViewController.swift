//
//  RegistrationWaitingViewController.swift
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
import ResearchUI
import Research
import BridgeSDK

class RegistrationWaitingViewController: RSDStepViewController {
    @IBOutlet weak var phoneLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.phoneLabel.text = (self.taskController as? SignInTaskViewController)?.phoneNumber
    }
    
    @IBAction func didTapChangeMobileButton(_ sender: Any) {
        // TODO emm 2018-05-03 get this working
//        guard let answerFormat = formItem.answerFormat as? SBATextResultCreator else { return }
//
//        let alertController = UIAlertController(title: formItem.text, message: "", preferredStyle: .alert)
//
//        let saveAction = UIAlertAction(title: Localization.localizedString("JP_SUMBIT_BUTTON"), style: .default, handler: {
//            alert -> Void in
//
//            let textField = alertController.textFields![0] as UITextField
//            let result = answerFormat.result(with: formItem.identifier, textAnswer: textField.text)
//            self.stepResult.addResult(result)
//            self.reloadData()
//        })
//
//        let cancelAction = UIAlertAction(title: Localization.buttonCancel(), style: .default, handler: nil)
//
//        alertController.addTextField { (textField : UITextField!) -> Void in
//
//            textField.text = currentText
//            textField.keyboardType = answerFormat.keyboardType
//            textField.placeholder = answerFormat.placeholder
//        }
//
//        alertController.addAction(cancelAction)
//        alertController.addAction(saveAction)
//
//        self.present(alertController, animated: true, completion: nil)
    }
}
