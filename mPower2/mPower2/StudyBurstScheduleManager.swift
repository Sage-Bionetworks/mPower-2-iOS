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
    public var progress : Double {
        return Double(finishedSchedules.count) / Double(totalActivitiesCount)
    }
    
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
    
    /// Override to get past 14 days of study burst markers and today's activities.
    override func fetchRequests() -> [SBAScheduleManager.FetchRequest] {
        guard let group = self.activityGroup else {
            return super.fetchRequests()
        }
        
        let requests: [FetchRequest] = group.activityIdentifiers.map {
            var predicate = SBBScheduledActivity.activityIdentifierPredicate(with:$0.stringValue)
            if $0 == .studyBurstCompletedTask {
                let start = Date().startOfDay().addingNumberOfDays(-1 * self.numberOfDays)
                let end = Date().startOfDay().addingNumberOfDays(1)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    SBBScheduledActivity.availablePredicate(from: start, to: end),
                    predicate])
            }
            else {
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    SBBScheduledActivity.availableTodayPredicate(),
                    predicate])
            }
            return FetchRequest(predicate: predicate, sortDescriptors: nil, fetchLimit: nil)
        }
        return requests
    }
    
    /// Override to build the new set of today history items.
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        
        if let studyMarker = self.studyMarker() {
            
            self.hasStudyBurst = true
            
            let todayStart = Date().startOfDay()
            let pastSchedules = self.scheduledActivities.filter { $0.scheduledOn < todayStart }
            self.dayCount = pastSchedules.count + 1
            self.missedDaysCount = pastSchedules.reduce(0, { $0 + ($1.finishedOn == nil ? 1 : 0) })
            
            if studyMarker.finishedOn != nil {
                self._expiresOn = nil
                self.finishedSchedules = self.scheduledActivities.filter {
                    $0.activityIdentifier != studyMarker.activityIdentifier &&
                    Calendar.current.isDateInToday($0.scheduledOn)
                }
            }
            else {
                let (schedules, startedOn, finishedOn) = self.filterFinishedSchedules(self.scheduledActivities)
                self.finishedSchedules = schedules
                if self.totalActivitiesCount == schedules.count, let finishedOn = finishedOn {
                    // The activities for today were marked as finished by a different schedule manager.
                    self._expiresOn = nil
                    studyMarker.startedOn = startedOn ?? Date()
                    studyMarker.finishedOn = finishedOn
                    super.sendUpdated(for: [studyMarker])
                }
                else {
                    self._expiresOn = finishedOn?.addingTimeInterval(expiresLimit)
                }
            }
        }
        else {
            self.hasStudyBurst = false
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
    override func sendUpdated(for schedules: [SBBScheduledActivity]) {
        DispatchQueue.main.async {

            let unionedSchedules = self.unionSchedules(self.finishedSchedules, updatedSchedules: schedules)
            let (finishedSchedules, startedOn, finishedOn) = self.filterFinishedSchedules(unionedSchedules, gracePeriod: 10 * 60)
            self.finishedSchedules = finishedSchedules
            var sendSchedules = schedules
            if self.totalActivitiesCount == schedules.count, let finishedOn = finishedOn,
                let studyMarker = self.studyMarker(), studyMarker.finishedOn == nil {
                self._expiresOn = nil
                studyMarker.startedOn = startedOn ?? Date()
                studyMarker.finishedOn = finishedOn
                sendSchedules.append(studyMarker)
            }
            
            super.sendUpdated(for: sendSchedules)
        }
    }
    
    /// Returns the study burst completed marker for today.
    func studyMarker() -> SBBScheduledActivity? {
        return self.scheduledActivities.first(where: {
            Calendar.current.isDateInToday($0.scheduledOn) && $0.activityIdentifier == RSDIdentifier.studyBurstCompletedTask.stringValue
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
        let finishedPredicate = SBBScheduledActivity.finishedOnOrAfterPredicate(startTimeWindow().addingTimeInterval(-1 * gracePeriod))
        var finishedOn : Date?
        var startedOn : Date?
        let results = schedules.filter {
            if Calendar.current.isDateInToday($0.scheduledOn) && finishedPredicate.evaluate(with: $0) {
                if (finishedOn == nil) || ($0.finishedOn! < finishedOn!) {
                    finishedOn = $0.finishedOn
                    startedOn = $0.startedOn
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
