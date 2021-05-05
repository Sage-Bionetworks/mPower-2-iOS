//
//  ProfileTableViewController.swift
//  mPower2
//
//  Copyright © 2016-2019 Sage Bionetworks. All rights reserved.
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

class ProfileTableViewController: UITableViewController, RSDTaskViewControllerDelegate {
    
    static let detailCellIdentifier = "ProfileTableViewDetailCell"
    static let cellIdentifier = "ProfileTableViewCell"
    
    static let settingsViewControllerSegueId = "SettingsViewControllerSegue"
    
    // Hard-coded to match Config Element on bridge
    static let birthYearIndexPath = IndexPath(row: 1, section: 0)
    static let sexIndexPath = IndexPath(row: 2, section: 0)
    
    var webViewControllerStoryboardId = "ProfileHTMLViewController"
    var withdrawalViewControllerStoryboardId = "WithdrawalViewController"
    var subProfileViewControllerStoryboardId = "SubProfileTableViewController"
    var profileItemEditViewControllerStoryboardId = "ProfileItemEditViewController"
    var settingsViewControllerStoryboardId = "SettingsViewController"
    
    private var _profileStoryboard: UIStoryboard?
    var profileStoryboard: UIStoryboard {
        get {
            return self._profileStoryboard ?? self.storyboard ?? UIStoryboard(name: "main", bundle: Bundle.main)
        }
        set {
            self._profileStoryboard = newValue
        }
    }
    
    private var _profileDataSource: SBAProfileDataSource?
    var profileDataSource: SBAProfileDataSource {
        get {
            return self._profileDataSource ?? SBAProfileDataSourceObject.shared
        }
        set {
            self._profileDataSource = newValue
        }
    }
    
    var navBarTranslucency: Bool = true
    
    @IBInspectable var hideSectionHeaderSeparator: Bool = false
    @IBOutlet weak var tableHeaderView: UIView!
    @IBOutlet weak var headerTitleLabel: UILabel!
    @IBOutlet weak var tableFooterView: UIView!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    
    @IBAction func backButtonTapped(_ sender: Any!) {
        navigationController?.popViewController(animated: true)
    }

    
    open func registerSectionHeaderView() {
        tableView.register(UINib.init(nibName: ProfileTableHeaderView.className, bundle: nil), forHeaderFooterViewReuseIdentifier: ProfileTableHeaderView.className)
    }
    
    open func registerSectionFooterView() {
        tableView.register(UINib.init(nibName: ProfileTableFooterView.className, bundle: nil), forHeaderFooterViewReuseIdentifier: ProfileTableFooterView.className)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let designSystem = RSDDesignSystem()
        let background = designSystem.colorRules.backgroundPrimary
        
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        versionLabel?.text = "\(Localization.localizedAppName) \(version!), build \(Bundle.main.appVersion())"
        tableView.backgroundColor = UIColor.white
        tableHeaderView?.backgroundColor = background.color
        headerTitleLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .mediumHeader)
        tableFooterView?.backgroundColor = background.color
        versionLabel?.textColor = designSystem.colorRules.textColor(on: background, for: .bodyDetail)
        
        registerSectionHeaderView()
        registerSectionFooterView()
        
        NotificationCenter.default.addObserver(forName: .SBAUpdatedReports, object: nil, queue: .main) { (_) in
            self.tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return profileDataSource.numberOfSections()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return profileDataSource.numberOfRows(for: section)
    }
    
    func itemForRow(at indexPath: IndexPath) -> SBAProfileTableItem? {
        return profileDataSource.profileTableItem(at: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableItem = itemForRow(at: indexPath)
        let titleText = tableItem?.title
        let detailText = tableItem?.detail
        let identifier = (detailText == nil) ? ProfileTableViewController.cellIdentifier : ProfileTableViewController.detailCellIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! ProfileTableViewCell
        
        // Configure the cell...
        cell.titleLabel?.text = titleText
        cell.detailLabel?.text = detailText
        if let pvpTableItem = tableItem as? SBAProfileViewProfileTableItem {
            cell.icon?.image = pvpTableItem.icon
        }
        cell.chevron?.isHidden = !self.shouldShowChevron(for: tableItem)
        
        return cell
    }
    
    func shouldShowChevron(for tableItem: SBAProfileTableItem?) -> Bool {
        guard let item = tableItem, let onSelected = item.onSelected else { return false }
        switch onSelected {
        case .showHTML:
            if let htmlItem = item as? SBAHTMLProfileTableItem,
                htmlItem.url != nil {
                return true
            }
            else {
                return false
            }
            
        case .editProfileItem:
            if let profileTableItem = item as? SBAProfileItemProfileTableItem,
                (profileTableItem.isEditable ?? false) {
                    return true
            }
            else {
                return false
            }
        
        case .settingsProfileAction:
            if let settingsTableItem = item as? SettingsProfileTableItem,
                (settingsTableItem.isEditable ?? false) {
                    return true
            }
            else {
                return false
            }

        case .showWithdrawal,
             .showProfileView,
             .permissionsProfileAction,
             .mailToProfileAction:
            return true
            
        default:
            return false
        }
    }
    
    func viewController(for identifier: String) -> UIViewController {
        return self.profileStoryboard.instantiateViewController(withIdentifier: identifier)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let item = itemForRow(at: indexPath),
                let onSelected = item.onSelected
            else {
                return
        }
        
        switch onSelected {
        case .showHTML:
            guard let htmlItem = item as? SBAHTMLProfileTableItem else { break }
            guard let webVC = self.viewController(for: self.webViewControllerStoryboardId) as? RSDWebViewController
                else { return }
            webVC.url = htmlItem.url
            self.show(webVC, sender: self)

        case .showWithdrawal:
            guard let withdrawalVC = self.viewController(for: self.withdrawalViewControllerStoryboardId) as? WithdrawalViewController else { return }
            self.show(withdrawalVC, sender: self)
            
        case .editProfileItem:
            guard let profileTableItem = item as? SBAProfileItemProfileTableItem,
                (profileTableItem.isEditable ?? false)
                else {
                    return
            }
            if profileTableItem.editTaskIdentifier != nil {
                self.showTask(for: profileTableItem, at: indexPath)
            }
            else if profileTableItem.choices != nil {
                self.showChoices(for: profileTableItem, at: indexPath)
            }
            else {
                self.showPopoverTextbox(for: profileTableItem, at: indexPath)
            }
        
        case .settingsProfileAction:
            guard let settingsTableItem = item as? SettingsProfileTableItem,
                (settingsTableItem.isEditable ?? false)
                else {
                    return
            }
            self.showTask(for: settingsTableItem, at: indexPath)

        case .showProfileView:
            guard let profileViewTableItem = item as? SBAProfileViewProfileTableItem
                else {
                    return
            }
            guard let profileVC = self.viewController(for: self.subProfileViewControllerStoryboardId) as? ProfileTableViewController
                else { return }
            profileVC.profileDataSource = profileViewTableItem.profileDataSource
            self.show(profileVC, sender: self)
            
        case .permissionsProfileAction:
            guard let permissionsItem = item as? PermissionsProfileTableItem else { break }
            let status = RSDAuthorizationHandler.authorizationStatus(for: permissionsItem.permissionType.identifier)
            let permission = RSDStandardPermission(permissionType: permissionsItem.permissionType)
            if status == .notDetermined {
                // If permission has never been granted then request it and reload the row.
                RSDAuthorizationHandler.requestAuthorization(for: permission) { [weak self] (_, _) in
                    self?.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
            else if status != .restricted,
                let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(settingsUrl) {
                // If the status is *not* restricted and the settings are accessible,
                // then open them. Note: preferred UI/UX is to go to the app without confirmation
                // and let the user return via the back button.
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
            else {
                // If the permission is restricted then there is no point in redirecting to the
                // settings app. Just show the restricted message.
                self.presentAlertWithOk(title: permission.title,
                                        message: permission.restrictedMessage) { (_) in
                }
            }
        
        case .mailToProfileAction:
            guard let mailTo = item as? MailToProfileTableItem else { return }
            let version = versionLabel?.text ?? ""
            let device = UIDevice.current.deviceInfo() ?? ""
            let footer = "\n---\n\(version)\n\(device)"
            let body = footer.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
            let urlString = "mailto:\(mailTo.email)?body=\(body)"
            guard let mailURL = URL(string: urlString),
                UIApplication.shared.canOpenURL(mailURL)
                else {
                    // Cannot open the email application so just present a popup.
                    // If the phone restricts access to email or doesn't have it set up, we can't
                    // do anything futher.
                    let message = String.localizedStringWithFormat(
                        Localization.localizedString("MAILTO_FAILED_MESSAGE_%@"), mailTo.email)
                    self.presentAlertWithOk(title: nil, message: message, actionHandler: nil)
                    return
            }
            UIApplication.shared.open(mailURL, options: [:], completionHandler: nil)

            /* TODO: emm 2018-08-21 deal with this for v2.1
            
        case downloadDataAction:
            self.performSegue(withIdentifier: "downloadDataSegue", sender: self)
            break
            */
            
        default:
            // do nothing
            break
        }
    }
    
    func showTask(for profileTableItem: TaskProfileTableItem, at indexPath: IndexPath) {
        guard let taskId = profileTableItem.editTaskIdentifier,
                let profileManager = profileTableItem.taskManager
            else {
                return
        }
        let taskInfo = RSDTaskInfoObject(with: taskId)
        let taskViewModel = profileManager.instantiateTaskViewModel(for: taskInfo).taskViewModel

        guard let editVC = self.viewController(for: self.profileItemEditViewControllerStoryboardId) as? ProfileItemEditViewController
            else { return }
        editVC.taskViewModel = taskViewModel
        editVC.taskViewModel.taskController = editVC
        editVC.profileTableItem = profileTableItem
        editVC.delegate = self
        editVC.indexPath = indexPath
        self.show(editVC, sender: self)
    }
    
    func showPopoverTextbox(for profileTableItem: SBAProfileItemProfileTableItem, at indexPath: IndexPath) {
        guard let profileItem = profileTableItem.profileItem else { return }
        
        let ac = UIAlertController(title: profileTableItem.title, message: nil, preferredStyle: .alert)
        ac.addTextField { (textField) in
            textField.text = "\(profileItem.value ?? "")"
        }

        let submitAction = UIAlertAction(title: Localization.localizedString("BUTTON_SAVE"), style: .default) { [unowned ac, weak self] _ in
            guard let answer = ac.textFields![0].text, !answer.isEmpty else { return }
            let answerType = profileItem.itemType.defaultAnswerResultType()
            do {
                profileItem.value = try answerType.jsonEncode(from: answer)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            catch let err {
                print("WARNING! Failed to encode the text String to \(answerType): \(err)")
            }
        }
        ac.addAction(submitAction)
        
        let cancelAction = UIAlertAction(title: Localization.buttonCancel(), style: .cancel) { (_) in
        }
        ac.addAction(cancelAction)

        present(ac, animated: true)
    }
    
    func showChoices(for profileTableItem: SBAProfileItemProfileTableItem, at indexPath: IndexPath) {

        guard let profileItem = profileTableItem.profileItem,
            let choices = profileTableItem.choices
            else {
                return
        }
        
        let formInput = RSDChoiceInputFieldObject(identifier: profileItem.demographicKey,
                                                  choices: choices,
                                                  dataType: profileItem.itemType)
        let formStep = RSDFormUIStepObject(identifier: profileItem.demographicKey, inputFields: [formInput])
        var navigator = RSDConditionalStepNavigatorObject(with: [formStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: "ProfileTempTask", stepNavigator: navigator)
        let taskViewModel = RSDTaskViewModel(task: task)
        let answerResult = RSDAnswerResultObject(identifier: profileItem.demographicKey, answerType: profileItem.itemType.defaultAnswerResultType(), value: profileItem.value)
        taskViewModel.append(previousResult: answerResult)

        guard let editVC = self.viewController(for: self.profileItemEditViewControllerStoryboardId) as? ProfileItemEditViewController
            else { return }
        editVC.taskViewModel = taskViewModel
        editVC.taskViewModel.taskController = editVC
        editVC.profileTableItem = profileTableItem
        editVC.delegate = self
        editVC.indexPath = indexPath
        self.show(editVC, sender: self)
    }
        
    func showGoToSettingsAlert() {
        let title = Localization.localizedString("JP_SETTINGS_TITLE")
        let format = Localization.localizedString("JP_SETTINGS_MESSAGE_FORMAT")
        let message = String.localizedStringWithFormat(format, Localization.localizedAppName)
        presentAlertWithYesNo(title: title, message: message, actionHandler: { (yes) in
            guard yes else { return }
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
            }
        })
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let tableItem = itemForRow(at: indexPath) else { return false }
        return tableItem.isEditable ?? false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueId = segue.identifier else { return }
        switch segueId {
        case ProfileTableViewController.settingsViewControllerSegueId:
            guard let settingsVC = segue.destination as? ProfileTableViewController
                else { return }
            settingsVC.profileDataSource = SBABridgeConfiguration.shared.profileDataSource(for: "SettingsDataSource")!
        default:
            // do nothing
            break
        }
    }
    
    // MARK: Table view delegate
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = profileDataSource.title(for: section) else { return nil }
        
        let sectionHeaderView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ProfileTableHeaderView.className) as! ProfileTableHeaderView
        sectionHeaderView.titleLabel?.text = title
        sectionHeaderView.separatorLine?.isHidden = self.hideSectionHeaderSeparator
        
        return sectionHeaderView
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard profileDataSource.title(for: section) != nil else { return CGFloat.leastNormalMagnitude }
        
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView.estimatedSectionHeaderHeight
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.tableView.estimatedRowHeight
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let sectionFooterView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ProfileTableFooterView.className) as! ProfileTableFooterView
        
        return sectionFooterView
    }
    
    // This method will be called when a schedule timing task is updated, so update the UI
    func scheduleUpdated() {
        self.tableView.reloadData()
    }
    
    // MARK: RSDTaskControllerDelegate
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        self.tableView.reloadData()
        self.navigationController?.popViewController(animated: true)
        
        if let editVC = taskController as? ProfileItemEditViewController,
            let profileManager = editVC.profileTableItem?.taskManager {
            profileManager.taskController(taskController, didFinishWith: reason, error: error)
        }
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        guard let editVC = taskController as? ProfileItemEditViewController,
            let profileTableItem = editVC.profileTableItem,
            let indexPath = editVC.indexPath
            else {
                assertionFailure("Do not have a means to save this task.")
                return
        }
            
        if let profileManager = profileTableItem.taskManager {
            profileManager.taskController(taskController, readyToSave: taskViewModel)
        }
        else if let profileItem = (profileTableItem as? SBAProfileItemProfileTableItem)?.profileItem,
            let answerResult = taskViewModel.taskResult.findAnswerResult(with: profileItem.demographicKey) {
            profileItem.value = answerResult.value
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
        else {
            assertionFailure("Do not have a means to save this task.")
        }
    }
}
