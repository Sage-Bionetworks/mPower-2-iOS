//
//  HistoryItem+Custom.swift
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
import CoreData
import BridgeApp
import DataTracking

extension HistoryItem {
    
    convenience init(context: NSManagedObjectContext, report: SBAReport) {
        self.init(context: context)
        self.reportDate = report.date
        self.reportIdentifier = report.identifier
        self.category = report.category.rawValue
        self.timestampDate = report.date
        self.dateBucket = report.date.dateBucket(for: report.timeZone)
        self.timeZoneSeconds = Int32(report.timeZone.secondsFromGMT(for: report.date))
        self.timeZoneIdentifier = report.timeZone.identifier
    }
    
    /// The timezone when the item was marked.
    var timeZone: TimeZone {
        if let identifier = self.timeZoneIdentifier, let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }
        else if let timeZone = TimeZone(secondsFromGMT: Int(self.timeZoneSeconds)) {
            return timeZone
        }
        else {
            return TimeZone.current
        }
    }
    
    /// The timestamp (Date) for when the item was marked as "done".
    var timestamp: Date {
        return self.timestampDate ?? Date()
    }
   
    /// Localized date to display to the participant.
    var localizedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.timeZone = self.timeZone
        return formatter.string(from: self.timestamp)
    }
    
    /// Localized time to display to the participant.
    var localizedTime: String {
        // Get the time from the timestamp.
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = self.timeZone
        let timeString = formatter.string(from: self.timestamp)
        
        // If the participant's time zone has changed at some point "today" then show the time zone
        // to clarify what's going on. This is pretty edge-case but the expected scenario is someone
        // visiting family or vacationing, and the "time of day" gets all messed up. It's likely that
        // for something like medication, this won't work b/c they will be marking their meds based
        // on the "Yes, I took them" and not thinking "well, yes, I took them, but not at that time
        // in that locale", but... yeah. syoung 07/18/2019
        if self.timeZoneChanged,
            let zoneIdentifier = self.timeZone.localizedName(for: .shortStandard, locale: nil) {
            return String.localizedStringWithFormat("%@ (%@)", timeString, zoneIdentifier)
        }
        else {
            return timeString
        }
    }

    /// The day of the week, today, or yesterday depending upon the date.
    var localizedDay: String? {
        var calendar = Calendar.current
        calendar.timeZone = self.timeZone
        let timestamp = self.timestamp
        
        // TODO: syoung 07/18/2019 I am not sure this will work for all languages. Do all languages
        // have a concept of "Yesterday" or "Today"?
        if calendar.isDateInToday(timestamp) {
            return Localization.localizedString("HISTORY_TITLE_TODAY")
        }
        else if let offsetDate = calendar.date(byAdding: .day, value: 1, to: timestamp),
            calendar.isDateInToday(offsetDate) {
            return Localization.localizedString("HISTORY_TITLE_YESTERDAY")
        }
        else {
            return RSDWeekday(rawValue: calendar.component(.weekday, from: timestamp))?.text
        }
    }
    
    /// The task image icon.
    var image: UIImage? {
        let imageName = self.imageName ?? "ActivitiesTaskIcon"
        return UIImage(named: imageName)
    }
}

extension TriggerHistoryItem {
    
    convenience init(context: NSManagedObjectContext, report: SBAReport, result: SBATriggerResult, loggedDate: Date) {
        self.init(context: context)
        self.reportDate = report.date
        self.reportIdentifier = report.identifier
        self.category = report.category.rawValue
        self.identifier = result.identifier
        let timeZone = result.timeZone
        self.timestampDate = loggedDate
        self.dateBucket = loggedDate.dateBucket(for: timeZone)
        self.timeZoneSeconds = Int32(timeZone.secondsFromGMT(for: loggedDate))
        self.timeZoneIdentifier = timeZone.identifier
        self.imageName = "TriggersTaskIcon"
        self.title = result.text
    }
}

extension SymptomHistoryItem {
    
    convenience init(context: NSManagedObjectContext, report: SBAReport, result: SBASymptomResult, loggedDate: Date) {
        self.init(context: context)
        self.reportDate = report.date
        self.reportIdentifier = report.identifier
        self.category = report.category.rawValue
        self.identifier = result.identifier
        let timeZone = result.timeZone
        self.timestampDate = loggedDate
        self.dateBucket = loggedDate.dateBucket(for: timeZone)
        self.timeZoneSeconds = Int32(timeZone.secondsFromGMT(for: loggedDate))
        self.timeZoneIdentifier = timeZone.identifier
        self.imageName = "SymptomsTaskIcon"
        self.title = result.text
        self.durationLevel = Int64(result.duration?.rawValue ?? -1)
        self.severityLevel = Int64(result.severity?.rawValue ?? 0)
        self.note = result.notes
        self.medicationTiming = result.medicationTiming?.rawValue
    }
}
