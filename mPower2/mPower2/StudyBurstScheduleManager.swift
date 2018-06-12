//
//  StudyBurstScheduleManager.swift
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
import BridgeApp

/// The study burst manager is accessible on the "Today" view as well as being used to manage the study burst
/// view controller.
class StudyBurstScheduleManager : SBAScheduleManager {
    
    /// The number of days in the study burst.
    public var numberOfDays: Int = 14
    
    /// The time limit until the progress expires.
    public var expiresLimit: TimeInterval = 60 * 60
    
    /// Is there an active study burst?
    public private(set) var hasStudyBurst : Bool = false
    
    /// What day of the study burst should be displayed?
    public private(set) var dayCount : Int?
    
    /// Number of days in the study burst that were missed.
    public private(set) var missedDaysCount: Int = 0
    
    /// When does the study burst expire?
    public var expiresOn : Date? {
        guard let expiresOn = _expiresOn else { return nil }
        if expiresOn > Date() {
            return expiresOn
        }
        else {
            DispatchQueue.main.async {
                self.didUpdateScheduledActivities(from: self.scheduledActivities)
            }
            return nil
        }
    }
    private var _expiresOn : Date?
    
    /// What is the current progress on required activities?
    public var progress : CGFloat {
        return CGFloat(finishedSchedules.count) / CGFloat(totalActivitiesCount)
    }
    
    /// Today marker used to update the schedules.
    public private(set) var today: Date?
    
    /// Is the Study burst completed for today?
    public var isCompletedForToday : Bool {
        return !hasStudyBurst || (finishedSchedules.count == totalActivitiesCount)
    }
    
    /// Total number of activities
    public var totalActivitiesCount : Int {
        return (activityGroup?.activityIdentifiers.count ?? 1) - 1
    }
    
    /// Subset of the finished schedules.
    public private(set) var finishedSchedules: [SBBScheduledActivity] = []
    
    /// Returns an ordered set of task info objects. This will change each day, but should retain the saved
    /// order for any given day.
    public func orderedTasks() -> [RSDTaskInfo] {
        guard let tasks = self.activityGroup?.tasks else {
            return []
        }

        let userDefaults = UserDefaults.standard
        let orderKey = "StudyBurstTaskOrder"
        let timestampKey = "StudyBurstTimestamp"
        
        if let storedOrder = userDefaults.array(forKey: orderKey) as? [String],
            let timestamp = userDefaults.object(forKey: timestampKey) as? Date,
            Calendar.current.isDateInToday(timestamp) {
            // If the timestamp is still valid for today, then sort using the stored order.
            return tasks.sorted(by: {
                guard let idx1 = storedOrder.index(of: $0.identifier),
                    let idx2 = storedOrder.index(of: $1.identifier)
                    else {
                        return false
                }
                return idx1 < idx2
            })
        }
        else {
            // Otherwise, shuffle the tasks and store order of the the task identifiers.
            var shuffledTasks = tasks
            shuffledTasks.shuffle()
            let sortOrder = shuffledTasks.map { $0.identifier }
            userDefaults.set(sortOrder, forKey: orderKey)
            userDefaults.set(Date(), forKey: timestampKey)
            return shuffledTasks
        }
    }
    
    /// Override to get past 14 days of study burst markers and today's activities.
    override func fetchRequests() -> [SBAScheduleManager.FetchRequest] {
        guard let group = self.activityGroup else {
            return super.fetchRequests()
        }

        let predicates: [NSPredicate] = group.activityIdentifiers.map {
            let predicate = SBBScheduledActivity.activityIdentifierPredicate(with:$0.stringValue)
            let start: Date
            let end: Date
            if $0 == .studyBurstCompletedTask {
                start = Date().startOfDay().addingNumberOfDays(-2 * self.numberOfDays)
                end = Date().startOfDay().addingNumberOfDays(2 * self.numberOfDays)
            }
            else {
                start = Date().startOfDay()
                end = start.addingNumberOfDays(1)
            }
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                SBBScheduledActivity.availablePredicate(from: start, to: end),
                predicate])
        }
        let filter = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        return [FetchRequest(predicate: filter, sortDescriptors: nil, fetchLimit: nil)]
    }
    
    /// Override to build the new set of today history items.
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        guard (today == nil) || !Calendar.current.isDateInToday(today!) || !isCompletedForToday
            else {
                return
        }
        today = Date()
        
        if let studyMarker = self.studyMarker() {
            self.hasStudyBurst = true
            
            var schedules = self.scheduledActivities
            let markerSchedules = schedules.remove(where: { studyMarker.activityIdentifier == $0.activityIdentifier })
            
            let todayStart = Date().startOfDay()
            let pastSchedules = markerSchedules.filter {
                $0.scheduledOn < todayStart && studyMarker.activityIdentifier == $0.activityIdentifier
            }
            self.numberOfDays = schedules.count
            self.dayCount = pastSchedules.count + 1
            self.missedDaysCount = pastSchedules.reduce(0, { $0 + ($1.finishedOn == nil ? 1 : 0) })
            
            if studyMarker.isCompleted {
                self._expiresOn = nil
                self.finishedSchedules = self.filterFinishedSchedules(schedules).0
            }
            else {
                let (filtered, startedOn, finishedOn) = self.filterFinishedSchedules(schedules)
                self.finishedSchedules = filtered
                if self.totalActivitiesCount == filtered.count, let finishedOn = finishedOn {
                    // The activities for today were marked as finished by a different schedule manager.
                    self.markCompleted(studyMarker: studyMarker, startedOn: startedOn, finishedOn: finishedOn, finishedSchedules: finishedSchedules)
                    super.sendUpdated(for: [studyMarker])
                }
                else {
                    self._expiresOn = finishedOn?.addingTimeInterval(expiresLimit)
                }
            }
        }
        else {
            self.hasStudyBurst = false
            self._expiresOn = nil
            self.dayCount = nil
        }

        super.didUpdateScheduledActivities(from: previousActivities)
    }
    
    /// Override isCompleted to only return true if the schedule is within the expiration window.
    override func isCompleted(for taskInfo: RSDTaskInfo, on date: Date) -> Bool {
        guard Calendar.current.isDateInToday(date) else {
            return super.isCompleted(for: taskInfo, on: date)
        }
        return self.finishedSchedules.first(where: { $0.activityIdentifier == taskInfo.identifier }) != nil
    }
    
    /// Override to update the finished schedules
    override func sendUpdated(for schedules: [SBBScheduledActivity], taskPath: RSDTaskPath? = nil) {
        guard taskPath == nil else {
            super.sendUpdated(for: schedules, taskPath:taskPath)
            return
        }
        
        DispatchQueue.main.async {

            let unionedSchedules = self.unionSchedules(self.finishedSchedules, updatedSchedules: schedules)
            let (finishedSchedules, startedOn, finishedOn) = self.filterFinishedSchedules(unionedSchedules, gracePeriod: 10 * 60)
            self.finishedSchedules = finishedSchedules
            var sendSchedules = schedules
            if self.totalActivitiesCount == schedules.count, let finishedOn = finishedOn,
                let studyMarker = self.studyMarker(), studyMarker.finishedOn == nil {
                self.markCompleted(studyMarker: studyMarker, startedOn: startedOn, finishedOn: finishedOn, finishedSchedules: finishedSchedules)
                sendSchedules.append(studyMarker)
            }
            
            super.sendUpdated(for: sendSchedules, taskPath: taskPath)
        }
    }
    
    func markCompleted(studyMarker: SBBScheduledActivity, startedOn: Date?, finishedOn: Date, finishedSchedules: [SBBScheduledActivity]) {
        
        self._expiresOn = nil
        studyMarker.startedOn = startedOn ?? Date()
        studyMarker.finishedOn = finishedOn
        
        guard let identifier = studyMarker.activityIdentifier,
            let schemaInfo = studyMarker.schemaInfo else {
                return
        }
        
        do {
        
            // build the archive
            let archive = SBAScheduledActivityArchive(identifier: identifier, schemaInfo: schemaInfo, schedule: studyMarker)
            var json: [String : Any] = [ "taskOrder" : self.orderedTasks().map { $0.identifier }.joined(separator: ",")]
            finishedSchedules.forEach {
                guard let identifier = $0.activityIdentifier, let finishedOn = $0.finishedOn else { return }
                json[identifier] = [
                    "startDate": ($0.startedOn ?? Date()).jsonObject(),
                    "endDate": finishedOn.jsonObject(),
                    "scheduleGuid": $0.guid
                ]
            }
            archive.insertDictionary(intoArchive: json, filename: "tasks", createdOn: finishedOn)
            
            try archive.complete()
            
            self.offMainQueue.async {
                archive.encryptAndUploadArchive()
            }
        }
        catch let err {
            print("Failed to archive the study burst data. \(err)")
        }
        
    }
    
    /// Returns the study burst completed marker for today.
    func studyMarker() -> SBBScheduledActivity? {
        return self.scheduledActivities.first(where: {
            Calendar.current.isDateInToday($0.scheduledOn) &&
                $0.activityIdentifier == RSDIdentifier.studyBurstCompletedTask.stringValue
        })
    }
    
    /// What is the start of the expiration time window?
    func startTimeWindow() -> Date {
        return Date().addingTimeInterval(-1 * expiresLimit)
    }
    
    /// Create a union set of the schedules where the activity identifier is the same.
    func unionSchedules(_ previous: [SBBScheduledActivity], updatedSchedules: [SBBScheduledActivity]) -> [SBBScheduledActivity] {
        var schedules = previous
        updatedSchedules.forEach { (schedule) in
            if let idx = schedules.index(where: { $0.activityIdentifier == schedule.activityIdentifier }) {
                schedules.remove(at: idx)
            }
            schedules.append(schedule)
        }
        return schedules
    }
    
    /// Get the filtered list of finished schedules.
    func filterFinishedSchedules(_ schedules: [SBBScheduledActivity], gracePeriod: TimeInterval = 0) -> ([SBBScheduledActivity], startedOn: Date?, finishedOn: Date?) {
        let startWindow = startTimeWindow().addingTimeInterval(-1 * gracePeriod)
        var finishedOn : Date?
        var startedOn : Date?
        let results = schedules.filter {
            if let scheduleFinished = $0.finishedOn, scheduleFinished >= startWindow {
                if (finishedOn == nil) || (finishedOn! < scheduleFinished) {
                    finishedOn = scheduleFinished
                }
                if let scheduleStarted = $0.startedOn,
                    ((startedOn == nil) || (startedOn! > scheduleStarted)) {
                    startedOn = scheduleStarted
                }
                return true
            }
            else {
                return false
            }
        }
        return (results, startedOn, finishedOn)
    }
}

extension Array {
    
    mutating public func shuffle() {
        var last = self.count - 1
        while last > 0 {
            let rand = Int(arc4random_uniform(UInt32(last)))
            self.swapAt(last, rand)
            last -= 1
        }
    }
}
