//
//  DownloadDataViewController.swift
//  mPower2
//
//  Copyright © 2017-2018 Sage Bionetworks. All rights reserved.
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

class DownloadDataViewController: UIViewController, SBALoadingViewPresenter {

    @IBOutlet var startDateLabel: UILabel!
    @IBOutlet var startDateTextField: UITextField!
    var startDatePicker: UIDatePicker?
    
    @IBOutlet var endDateLabel: UILabel!
    @IBOutlet var endDateTextField: UITextField!
    var endDatePicker: UIDatePicker?
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        return formatter
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let toolBar = UIToolbar()
        toolBar.barStyle = UIBarStyle.default
        toolBar.isTranslucent = true
        toolBar.tintColor = UIColor.appGunmetal
        toolBar.sizeToFit()
        let doneButton = UIBarButtonItem(title: Localization.localizedString("DONE_BUTTON_TITLE"), style: .done, target: self, action: #selector(self.doneTapped))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        toolBar.setItems([spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        self.startDateTextField.inputAccessoryView = toolBar
        self.endDateTextField.inputAccessoryView = toolBar
        
        let startDate = MasterScheduledActivityManager.shared.startStudy
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())?.startOfDay() ?? Date() // end of day today
        
        self.startDateLabel.textColor = UIColor.appGunmetal
        self.startDateLabel.font = UIFont.appPerformanceCellTitleFont()
        self.startDateLabel.text = Localization.localizedString("JP_DOWNLOAD_DATA_START_DATE")
        
        self.startDateTextField.textColor = UIColor.appGunmetal
        self.startDateTextField.font = UIFont.appTextFieldFont()
        self.startDateTextField.text = self.dateFormatter.string(from: startDate)
        
        self.startDatePicker = UIDatePicker.init()
        self.startDatePicker?.datePickerMode = .date
        self.startDatePicker?.date = startDate
        self.startDatePicker?.minimumDate = startDate
        self.startDatePicker?.maximumDate = endDate
        self.startDatePicker?.addTarget(self, action: #selector(self.startDatePickerChanged(sender:)), for: .valueChanged)
        self.startDateTextField.inputView = self.startDatePicker
        
        self.endDateLabel.textColor = UIColor.appGunmetal
        self.endDateLabel.font = UIFont.appPerformanceCellTitleFont()
        self.endDateLabel.text = Localization.localizedString("JP_DOWNLOAD_DATA_END_DATE")
        
        self.endDateTextField.textColor = UIColor.appGunmetal
        self.endDateTextField.font = UIFont.appTextFieldFont()
        self.endDateTextField.text = self.dateFormatter.string(from: endDate)
        
        self.endDatePicker = UIDatePicker.init()
        self.endDatePicker?.datePickerMode = .date
        self.endDatePicker?.date = endDate
        self.endDatePicker?.minimumDate = startDate
        self.endDatePicker?.maximumDate = endDate
        self.endDatePicker?.addTarget(self, action: #selector(self.endDatePickerChanged(sender:)), for: .valueChanged)
        self.endDateTextField.inputView = self.endDatePicker
    }

    func startDatePickerChanged(sender: Any?) {
        self.startDateTextField.text = self.dateFormatter.string(from: self.startDatePicker?.date ?? Date())
    }
    
    func endDatePickerChanged(sender: Any?) {
        self.endDateTextField.text = self.dateFormatter.string(from: self.endDatePicker?.date ?? Date())
    }
    
    func doneTapped() {
        self.startDateTextField.resignFirstResponder()
        self.endDateTextField.resignFirstResponder()
    }
    
    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func downloadDataTapped() {
        
        guard let startDate = self.startDatePicker?.date,
            let endDate = self.endDatePicker?.date else {
            return
        }
        
        self.showLoadingView()
        SBBUserManager.default().emailDataToUser(from: startDate, to: endDate, completion: { [weak self] (response, error) in
            DispatchQueue.main.async {
                self?.hideLoadingView()
                if let errorUnwrapped = error {
                    let title = Localization.localizedString("ERROR_TITLE")
                    let message = errorUnwrapped.localizedDescription
                    self?.showAlertWithOk(title: title, message: message, actionHandler: nil)
                } else {
                    let title = Localization.localizedString("SUCCESS_TITLE")
                    let message = Localization.localizedString("DOWNLOAD_DATA_SUCCESS_MSG")
                    self?.showAlertWithOk(title: title, message: message, actionHandler: { (action) in
                        self?.dismiss(animated: true, completion: nil)
                    })
                }
            }
        })
    }
}
