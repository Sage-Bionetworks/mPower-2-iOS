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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        
        let profileManager = SBABridgeConfiguration.shared.profileManager(for: "ProfileManager")
        self.headerTitleLabel?.text = profileManager?.value(forProfileKey: "preferredName") as? String
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
        
        return cell
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

            /* TODO: emm 2018-09-23 deal with this for v2.1
        case SBAProfileOnSelectedAction.showResource:
            guard let resourceItem = itemForRow(at: indexPath) as? SBAResourceProfileTableItem else { break }
            switch resourceItem.resource {
            case "HealthProfile":
                self.performSegue(withIdentifier: ProfileTableViewController.healthProfileViewControllerSegue, sender: self)
                break
            default:
                // TODO: emm 2017-06-06 implement
                break
            }
             */

        case .showWithdrawal:
            guard let withdrawalVC = self.viewController(for: self.withdrawalViewControllerStoryboardId) as? WithdrawalViewController else { return }
            self.show(withdrawalVC, sender: self)
            
        case .editProfileItem:
            guard let profileTableItem = item as? SBAProfileItemProfileTableItem,
                    (profileTableItem.isEditable ?? false)!,
                    let taskId = profileTableItem.editTaskIdentifier,
                    let profileManager = profileTableItem.profileManager as? SBAScheduleManager
                else {
                    break
            }
            
            let taskInfo = RSDTaskInfoObject(with: taskId)
            let taskViewModel = profileManager.instantiateTaskViewModel(for: taskInfo).taskViewModel

            guard let editVC = self.viewController(for: self.profileItemEditViewControllerStoryboardId) as? ProfileItemEditViewController
                else { return }
            editVC.taskViewModel = taskViewModel
            editVC.taskViewModel.taskController = editVC
            editVC.profileTableItem = profileTableItem
            editVC.delegate = self
            self.show(editVC, sender: self)
            
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
            
            /* TODO: emm 2018-08-21 deal with this for v2.1
        case scheduleProfileAction:
            guard let scheduleItem = item as? ScheduleProfileTableItem,
                let taskId = scheduleItem.taskGroup.scheduleTaskIdentifier
            else {
                break
            }
            
            // Before we create the task VC, let's signal to the schedule manager
            // that we want to ignore the non-applicable completion step
            let previousState = MasterScheduledActivityManager.shared.alwaysIgnoreTimingIntroductionStepForScheduling
            MasterScheduledActivityManager.shared.alwaysIgnoreTimingIntroductionStepForScheduling = true
            let vc = MasterScheduledActivityManager.shared.createTaskViewController(for: taskId)
            MasterScheduledActivityManager.shared.alwaysIgnoreTimingIntroductionStepForScheduling = previousState
            
            if let vcUnwrapped = vc {
                present(vcUnwrapped, animated: true, completion: nil)
            }
            
        case settingsProfileAction:
            guard let settingsItem = item as? SettingsProfileTableItem else { break }
            let hasPermission = SBAPermissionsManager.shared.isPermissionGranted(for: settingsItem.permissionType)
            if hasPermission {
                showGoToSettingsAlert()
            }
            else {
                // If we don't have permission, we can't tell if we've never requested it, and if we haven't, there
                // will be nothing the participant can do about it when they get to the Settings app, so we'd better
                // request it here first.
                SBAPermissionsManager.shared.requestPermission(for: settingsItem.permissionType, completion: { (granted, error) in
                    // If we didn't have permission and now it's just been granted, there's no point in going to the Settings app now.
                    // If it's not granted, we don't know if they just denied it or if they did in the past, and it seems like
                    // they wouldn't tap on a permission item that was "Off" if they didn't want to grant it, so we'll offer
                    // them the option.
                    if !granted {
                        self.showGoToSettingsAlert()
                    }
                    else {
                        // We do need to update the display here, though.
                        self.tableView.reloadData()
                    }
                })
            }
            
        case downloadDataAction:
            self.performSegue(withIdentifier: "downloadDataSegue", sender: self)
            break
            */
            
        default:
            // do nothing
            break
        }
    }
        
    func showGoToSettingsAlert() {
        let title = Localization.localizedString("JP_SETTINGS_TITLE")
        let format = Localization.localizedString("JP_SETTINGS_MESSAGE_FORMAT")
        let message = String.localizedStringWithFormat(format, Localization.localizedAppName)
        presentAlertWithYesNo(title: title, message: message, actionHandler: { (yes) in
            guard yes else { return }
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
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
    
/* TODO: emm 2018-08-21 deal with this for v2.1
    // MARK: ORKStepViewControllerDelegate
    
    func stepViewController(_ stepViewController: ORKStepViewController, didFinishWith direction: ORKStepViewControllerNavigationDirection) {
        if (direction == .forward) {
            stepViewController.update(participantInfo: sharedUser, with: [stepViewController.step!.identifier])
            
            // If this is a data groups step then need to update the data groups
            if let dataGroupsStep = stepViewController.step as? SBADataGroupsStepProtocol,
                let stepResult = stepViewController.result {
                let newGroups = dataGroupsStep.union(previousGroups: self.sharedUser.dataGroups, stepResult: stepResult)
                self.sharedUser.updateDataGroups(Array(newGroups), completion: nil)
            }
            
            self.tableView.reloadData()
        }
        self.navigationController?.navigationBar.isTranslucent = self.navBarTranslucency
        self.navigationController?.popViewController(animated: true)
    }
    
    func stepViewControllerResultDidChange(_ stepViewController: ORKStepViewController) {
        // Do nothing - required
    }
    
    func stepViewControllerDidFail(_ stepViewController: ORKStepViewController, withError error: Error?) {
        // Do nothing - required
    }
    
    func stepViewController(_ stepViewController: ORKStepViewController, recorder: ORKRecorder, didFailWithError error: Error) {
        // Do nothing - required
    }
    
    func stepViewControllerHasPreviousStep(_ stepViewController: ORKStepViewController) -> Bool {
        return true // Show the back button
    }
    
    func stepViewControllerHasNextStep(_ stepViewController: ORKStepViewController) -> Bool {
        return false
    }
    
    func stepViewControllerWillAppear(_ stepViewController: ORKStepViewController) {
        self.navBarTranslucency = self.navigationController?.navigationBar.isTranslucent ?? true
        self.navigationController?.navigationBar.isTranslucent = false
    }
 */
    
    // This method will be called when a schedule timing task is updated, so update the UI
    func scheduleUpdated() {
        self.tableView.reloadData()
    }
    
    // MARK: RSDTaskControllerDelegate
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        self.navigationController?.popViewController(animated: true)
        let editVC = taskController as? ProfileItemEditViewController
        let profileTableItem = editVC?.profileTableItem
        if let profileManager = (profileTableItem?.profileManager ?? SBAProfileManagerObject.shared) as? SBAScheduleManager {
            profileManager.taskController(taskController, didFinishWith: reason, error: error)
        }
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        let editVC = taskController as? ProfileItemEditViewController
        if let profileManager = (editVC?.profileTableItem?.profileManager ?? SBAProfileManagerObject.shared) as? SBAScheduleManager {
            profileManager.taskController(taskController, readyToSave: taskViewModel)
        }
    }
    

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
