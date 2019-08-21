//
//  TodayScheduleManager.swift
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

import Foundation
import BridgeAppUI
import DataTracking

struct TodayHistoryItem : Equatable, Comparable {

    /// The type of the items in this collection.
    enum ItemType : String, Equatable {
        case symptoms, medication, triggers, activities, surveys
        
        var activityIdentifiers : [RSDIdentifier]? {
            switch self {
            case .symptoms:
                return [.symptomsTask]
            case .medication:
                return [.medicationTask]
            case .triggers:
                return [.triggersTask]
            case .activities:
                return RSDIdentifier.measuringTasks
            default:
                return nil
            }
        }
    }
    
    /// The item type.
    let type : ItemType
    
    /// The schedule identifiers used to create this object.
    let schedules : [SBBScheduledActivity]
    
    /// The item count.
    let count : Int
    
    /// The icon for this item.
    var icon: UIImage? {
        get {
            return UIImage(named: "\(self.type.stringValue.capitalized)TaskIcon")
        }
    }
    
    /// The title for the item.
    var title : String {
        let keyCount = (count == 1) ? "SINGULAR" : "PLURAL"
        let keyName = self.type.stringValue.uppercased()
        let key = "TASK_\(keyCount)_TERM_FOR_\(keyName)"
        return Localization.localizedStringWithFormatKey(key, count)
    }
    
    static let sortOrder: [ItemType] = [.symptoms, .medication, .triggers, .activities, .surveys]
    
    static func < (lhs: TodayHistoryItem, rhs: TodayHistoryItem) -> Bool {
        return sortOrder.firstIndex(of: lhs.type)! < sortOrder.firstIndex(of: rhs.type)!
    }
}

class TodayHistoryScheduleManager : SBAScheduleManager {
    
    func today() -> Date {
        return Date()
    }
    
    /// List of all the items in today's history.
    public private(set) var items = [TodayHistoryItem]()
    
    /// Override to fetch the schedules for all activities that were finished today.
    override func fetchRequests() -> [FetchRequest] {
        let finishedPredicate = SBBScheduledActivity.finishedOnDatePredicate(on: today())
        let studyBurstPredicate = NSCompoundPredicate(notPredicateWithSubpredicate:
            SBBScheduledActivity.activityIdentifierPredicate(with: RSDIdentifier.studyBurstCompletedTask.stringValue))
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [finishedPredicate, studyBurstPredicate])
        let fetchRequest = FetchRequest(predicate: predicate,
                                        sortDescriptors: nil,
                                        fetchLimit: nil)
        return [fetchRequest]
    }
        
    /// Override to build the new set of today history items.
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        let schedules = self.scheduledActivities
        let activitiesChanged = schedules != previousActivities
        // If nothing has changed, then swallow the update and do nothing.
        guard activitiesChanged else {
            return
        }
        
        offMainQueue.async {
            let items = self.consolidateItems(schedules)
            DispatchQueue.main.async {
                self.items = items
                self.superDidUpdateScheduledActivities(from: previousActivities)
            }
        }
    }
    
    /// Call through to super using an internal method that can be overridden by tests.
    func superDidUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        super.didUpdateScheduledActivities(from: previousActivities)
    }
    
    func consolidateItems(_ scheduledActivities: [SBBScheduledActivity]) -> [TodayHistoryItem] {
        var schedules = scheduledActivities
        let items = TodayHistoryItem.sortOrder.compactMap { (itemType) -> TodayHistoryItem? in
            let filteredSchedules : [SBBScheduledActivity] = {
                guard let activityIdentifiers = itemType.activityIdentifiers else { return schedules }
                let predicates = activityIdentifiers.map {
                    SBBScheduledActivity.activityIdentifierPredicate(with: $0.stringValue)
                }
                let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                return schedules.remove(where: { predicate.evaluate(with: $0) })
            }()
            
            let count: Int = {
                switch itemType {
                case .triggers, .symptoms:
                    let startDate = today().startOfDay()
                    let endDate = today().addingNumberOfDays(1).startOfDay()
                    let clientData = self.allClientData(with: itemType.activityIdentifiers!.first!.stringValue, from: startDate, to: endDate)
                    let decoder = SBAFactory.shared.createJSONDecoder()
                    return clientData.reduce(0, { (input, json) -> Int in
                        guard let dictionary = json as? NSDictionary,
                            let result = try? decoder.decode(SBATrackedLoggingCollectionResultObject.self, from: dictionary)
                            else {
                                return input
                        }
                        return input + result.loggingItems.filter { $0.loggedDate != nil }.count
                    })
                
                // TODO: syoung 06/04/2018 Implement counting the medication items rather than just the finished schedules.

                default:
                    return filteredSchedules.count
                }
            }()
            
            guard count > 0 else { return nil }
            return TodayHistoryItem(type: itemType, schedules: filteredSchedules, count: count)
        }
        return items
    }
    
    override open func reportQueries() -> [ReportQuery] {
        let tasks: [RSDIdentifier] = [.triggersTask, .symptomsTask, .medicationTask]
        return tasks.map { ReportQuery(reportKey: $0, queryType: .today, dateRange: nil) }
    }
}
