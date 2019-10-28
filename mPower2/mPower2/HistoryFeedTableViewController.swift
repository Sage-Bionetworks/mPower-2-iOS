//
//  HistoryFeedTableViewController.swift
//  mPower2
//
//  Copyright © 2019 Sage Bionetworks. All rights reserved.
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
import DataTracking
import CoreData

class HistoryFeedTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    let dataManager = HistoryDataManager.shared
    
    var fetchedResultsController: NSFetchedResultsController<HistoryItem>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add an observer for the persistent store being set up.
        if !self.loadFetchedResultsController() {
            NotificationCenter.default.addObserver(forName: .MP2DidLoadPersistentStore, object: nil, queue: .main) { (notification) in
                self.loadFetchedResultsController()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Force a re-fetch of the data when switching to this view controller.
        if let fetchedResultsController = self.fetchedResultsController {
            do {
                try fetchedResultsController.performFetch()
                self.tableView.reloadData()
            }
            catch let err {
                print("Unable to Perform Fetch Request. \(err)")
            }
        }
    }
    
    @discardableResult
    func loadFetchedResultsController() -> Bool {
        guard let container = self.dataManager.persistentContainer else {
            return false
        }
        
        // Create Fetch Request
        let request: NSFetchRequest<HistoryItem> = HistoryItem.fetchRequest()
        request.includesSubentities = true
        let dateBucketSort = NSSortDescriptor(key: #keyPath(HistoryItem.dateBucket), ascending: false)
        let timeSort = NSSortDescriptor(key: #keyPath(HistoryItem.timestampDate), ascending: true)
        request.sortDescriptors = [dateBucketSort, timeSort]
        
        // Create Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: container.viewContext, sectionNameKeyPath: #keyPath(HistoryItem.dateBucket), cacheName: nil)
        
        // Configure Fetched Results Controller
        fetchedResultsController.delegate = self
        
        self.fetchedResultsController = fetchedResultsController
        do {
            try fetchedResultsController.performFetch()
        }
        catch let err {
            print("Unable to Perform Fetch Request. \(err)")
        }
        
        self.tableView.reloadData()
        
        return true
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let items = fetchedResultsController?.sections?[section].objects as? [HistoryItem]
            else {
                return 0
        }
        return 1 + items.count + items.filter({ $0.timeBucket == nil }).count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.fetchItem(at: indexPath) {
            let cell = tableView.dequeueReusableCell(withIdentifier: item.reuseIdentifier, for: indexPath) as! HistoryFeedBaseTableViewCell
            cell.configure(for: item.item, indexPath: indexPath)
            return cell
        }
        else {
            return tableView.dequeueReusableCell(withIdentifier: "Empty", for: indexPath)
        }
    }
    
    /// This is a hack-around for not being able to set up constraints and nested sections as
    /// required by the design. Once the participants have been in the study for a longer period of
    /// time, this may need to be reviewed for performance, but should be ok for now.
    /// syoung 07/26/2019
    func fetchItem(at indexPath: IndexPath) -> (reuseIdentifier: String, item: HistoryItem)? {
        guard let items = fetchedResultsController?.sections?[indexPath.section].objects as? [HistoryItem],
            items.count > 0
            else {
                return nil
        }
        
        if indexPath.row == 0 {
            return ("Day", items[0])
        }
        else {
            var idx = 0
            var timeRows = 0
            while idx < items.count {
                let item = items[idx]
                if item.timeBucket == nil {
                    if (idx + timeRows + 1) == indexPath.row {
                        return ("Time", item)
                    }
                    else {
                        timeRows += 1
                    }
                }
                if (idx + timeRows + 1) == indexPath.row {
                    return ("HistoryItem", item)
                }
                idx += 1
            }
        }
        
        return nil
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch (type) {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        default:
            break;
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch (type) {
        case .insert:
            tableView.insertSections([sectionIndex], with: .fade)
        case .delete:
            tableView.deleteSections([sectionIndex], with: .fade)
        default:
            break;
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

class HistoryFeedBaseTableViewCell : UITableViewCell {
    func configure(for item: HistoryItem, indexPath: IndexPath) {
    }
}

class HistoryFeedTableViewCell : HistoryFeedBaseTableViewCell {
    
    @IBOutlet weak var taskIcon: UIImageView!
    @IBOutlet weak var taskTitleLabel: UILabel!
    @IBOutlet weak var dotView: UIView!
    @IBOutlet weak var taskDetailLabel: UILabel!
    @IBOutlet weak var dotWidth: NSLayoutConstraint!
    
    override func configure(for item: HistoryItem, indexPath: IndexPath) {
        
        let designSystem = RSDDesignSystem()
        let background = designSystem.colorRules.backgroundLight
        
        taskIcon.image = item.image
        taskTitleLabel.text = item.title
        taskTitleLabel.textColor = designSystem.colorRules.textColor(on: background, for: .mediumHeader)
        taskDetailLabel.textColor = designSystem.colorRules.textColor(on: background, for: .bodyDetail)
        
        if let symptomsItem = item as? SymptomHistoryItem,
            let severity = SBASymptomSeverityLevel(rawValue: Int(symptomsItem.severityLevel)) {
            // Show the dot and the detail label
            dotWidth.constant = 18
            dotView.layer.cornerRadius = dotWidth.constant / 2
            dotView.backgroundColor = designSystem.colorRules.severityColorScale.stroke(for: severity.rawValue, isSelected: true)
            switch severity {
            case .none:
                taskDetailLabel.text = Localization.localizedString("SYMPTOM_SEVERITY_NONE")
            case .mild:
                taskDetailLabel.text = Localization.localizedString("SYMPTOM_SEVERITY_MILD")
            case .moderate:
                taskDetailLabel.text = Localization.localizedString("SYMPTOM_SEVERITY_MODERATE")
            case .severe:
                taskDetailLabel.text = Localization.localizedString("SYMPTOM_SEVERITY_SEVERE")
            }
        }
        else {
            // If not a symptom, then hide the dot.
            dotView.backgroundColor = UIColor.clear
            dotWidth.constant = 0
            
            if let tapItem = item as? TapHistoryItem {
                // TODO: syoung 07/18/2019 This will work for English. Not sure how well this formatting
                // will work for other languages that do not separate with a comma.
                let left = tapItem.leftTapCount > 0 ?
                    String.localizedStringWithFormat(Localization.localizedString("HISTORY_ITEM_TAP_LEFT"), tapItem.leftTapCount) : ""
                let right = tapItem.rightTapCount >  0 ? String.localizedStringWithFormat(Localization.localizedString("HISTORY_ITEM_TAP_RIGHT"), tapItem.rightTapCount) : ""
                let spacer = left.isEmpty || right.isEmpty ? "" : ", "
                taskDetailLabel.text = "\(right)\(spacer)\(left)"
            }
            else {
                // No other task items support the detail at this time.
                taskDetailLabel.text = nil
            }
        }
    
        self.setNeedsUpdateConstraints()
        self.setNeedsLayout()
    }
}

class HistoryFeedDayTableViewCell : HistoryFeedBaseTableViewCell {
    
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func configure(for item: HistoryItem, indexPath: IndexPath) {

        dayLabel.text = item.localizedDay
        dateLabel.text = item.localizedDate
        
        let designSystem = RSDDesignSystem()
        let background = designSystem.colorRules.backgroundLight
        dayLabel.textColor = designSystem.colorRules.textColor(on: background, for: .largeHeader)
        dateLabel.textColor = designSystem.colorRules.textColor(on: background, for: .mediumHeader)
    }
}

class HistoryFeedTimeTableViewCell : HistoryFeedBaseTableViewCell {
    
    @IBOutlet weak var timeLabel: UILabel!
    
    override func configure(for item: HistoryItem, indexPath: IndexPath) {

        timeLabel.text = item.localizedTime
        
        let designSystem = RSDDesignSystem()
        let background = designSystem.colorRules.backgroundLight
        timeLabel.textColor = designSystem.colorRules.textColor(on: background, for: .mediumHeader)
    }
}
