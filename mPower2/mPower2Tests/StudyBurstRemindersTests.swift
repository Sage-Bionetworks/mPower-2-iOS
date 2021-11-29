//
//  StudyBurstRemindersTests.swift
//  mPower2Tests
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

import XCTest
@testable import mPower2TestApp
@testable import BridgeApp
import ResearchV2
import UserNotifications

class StudyBurstRemindersTests: StudyBurstTests {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testReminders_Day1() {
        let calendar = Calendar(identifier: .iso8601)
        
        var setup: StudySetup = .day1_tasksFinished_surveysFinished
        setup.reminderTime = "09:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(setup)
        let studySetup = scheduleManager.studySetup
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Test assumptions
        let reminderReport = scheduleManager._participantManager.reportDataObjects.first {
            $0.identifer == RSDIdentifier.studyBurstReminder.stringValue }
        XCTAssertNotNil(reminderReport)
        
        let studyBurstMarker = scheduleManager.scheduledActivities.first(where: {
            $0.activityIdentifier == scheduleManager.studyBurst.identifier &&
                calendar.isDate($0.scheduledOn, inSameDayAs: studySetup.now)
        })
        XCTAssertNotNil(studyBurstMarker)
        XCTAssertTrue(studyBurstMarker?.isCompleted ?? false)
        
        // Check that the scheduled reminder time is decoded correctly
        let scheduledReminderTime = scheduleManager.getReminderTime()
        XCTAssertNotNil(scheduledReminderTime)
        XCTAssertEqual(scheduledReminderTime?.hour, 9)
        XCTAssertEqual(scheduledReminderTime?.minute, 0)
        XCTAssertNil(scheduledReminderTime?.day)
        XCTAssertNil(scheduledReminderTime?.month)
        XCTAssertNil(scheduledReminderTime?.year)
        
        guard let reminderTime = scheduledReminderTime else {
            XCTFail("Failed to get the reminder time. Cannot continue testing.")
            return
        }
        
        let requests = scheduleManager.getLocalNotifications(after: reminderTime, with: [])
        
        // On day 1, with a reminder time in the future but the schedule for today complete,
        // should have day 2 - 19 reminders lined up.
        XCTAssertEqual(requests.add.count, 18)
        XCTAssertEqual(requests.removeIds.count, 0)
        if let reminder = requests.add.first?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.now.addingNumberOfDays(1)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 9)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
        
        if let reminder = requests.add.last?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.createdOn.addingNumberOfDays(18)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 9)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
        
        let noChanges = scheduleManager.getLocalNotifications(after: reminderTime, with: requests.add)
        XCTAssertEqual(noChanges.add.count, 0)
        XCTAssertEqual(noChanges.removeIds.count, 0)
        
        var dateComponents = DateComponents()
        dateComponents.hour = 14
        dateComponents.minute = 30
        let timeChange = scheduleManager.getLocalNotifications(after: dateComponents, with: requests.add)
        XCTAssertEqual(timeChange.add.count, 18)
        XCTAssertEqual(timeChange.removeIds.count, 18)
        
        if let reminder = timeChange.add.first?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.now.addingNumberOfDays(1)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: timeChange.add.first?.trigger)) nil or not of expected type")
        }
    }
    
    func testReminders_Day2() {
        let calendar = Calendar(identifier: .iso8601)
        
        var setup: StudySetup = .day2_tasksNotFinished_surveysFinished
        setup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(setup)
        let studySetup = scheduleManager.studySetup
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check that the scheduled reminder time is decoded correctly
        let scheduledReminderTime = scheduleManager.getReminderTime()
        XCTAssertNotNil(scheduledReminderTime)
        XCTAssertEqual(scheduledReminderTime?.hour, 14)
        XCTAssertEqual(scheduledReminderTime?.minute, 0)
        
        guard let reminderTime = scheduledReminderTime else {
            XCTFail("Failed to get the reminder time. Cannot continue testing.")
            return
        }
        
        let requests = scheduleManager.getLocalNotifications(after: reminderTime, with: [])
        
        // On day 2, with a reminder time in the future and the schedule for today incomplete,
        // should have day 2 - 19 reminders lined up.
        XCTAssertEqual(requests.add.count, 18)
        XCTAssertEqual(requests.removeIds.count, 0)
        if let reminder = requests.add.first?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.now
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
        
        if let reminder = requests.add.last?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.createdOn.addingNumberOfDays(18)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
    }
    
    func testReminders_Day11_AllDaysCompleted() {
        let calendar = Calendar(identifier: .iso8601)
        
        var setup: StudySetup = .day11_tasksFinished_noMissingDays
        setup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(setup)
        let studySetup = scheduleManager.studySetup
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check that the scheduled reminder time is decoded correctly
        let scheduledReminderTime = scheduleManager.getReminderTime()
        XCTAssertNotNil(scheduledReminderTime)
        XCTAssertEqual(scheduledReminderTime?.hour, 14)
        XCTAssertEqual(scheduledReminderTime?.minute, 0)
        
        guard let reminderTime = scheduledReminderTime else {
            XCTFail("Failed to get the reminder time. Cannot continue testing.")
            return
        }
        
        let requests = scheduleManager.getLocalNotifications(after: reminderTime, with: [])
        
        // On day 11, with no missed days and today's tasks finished, the schedule should be set up for
        // day 12-14, but **not** for days 15-19 because the minimum required number of study bursts has
        // already been completed. Additionally, the reminders should be set up for days 1-14 for the *next*
        // study burst.
        XCTAssertEqual(requests.add.count, 17)
        XCTAssertEqual(requests.removeIds.count, 0)
        if let reminder = requests.add.first?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.now.addingNumberOfDays(1)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
        
        if requests.add.count >= 3,
            let reminder = requests.add[2].trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.now.addingNumberOfDays(3)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
        
        if requests.add.count >= 4,
            let reminder = requests.add[3].trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.createdOn.addingNumberOfDays(90)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
    }
    
    func testReminders_Day21_AllDaysCompleted() {
        let calendar = Calendar(identifier: .iso8601)
        
        var setup: StudySetup = .day21_tasksFinished_noMissingDays
        setup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(setup)
        let studySetup = scheduleManager.studySetup
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check that the scheduled reminder time is decoded correctly
        let scheduledReminderTime = scheduleManager.getReminderTime()
        XCTAssertNotNil(scheduledReminderTime)
        XCTAssertEqual(scheduledReminderTime?.hour, 14)
        XCTAssertEqual(scheduledReminderTime?.minute, 0)
        
        guard let reminderTime = scheduledReminderTime else {
            XCTFail("Failed to get the reminder time. Cannot continue testing.")
            return
        }
        
        let requests = scheduleManager.getLocalNotifications(after: reminderTime, with: [])
        
        // On day 21, with no missed days and today's tasks finished, the schedule should be set up for
        // days 1-14 for the *next* study burst.
        XCTAssertEqual(requests.add.count, 14)
        XCTAssertEqual(requests.removeIds.count, 0)
        if let reminder = requests.add.first?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.createdOn.addingNumberOfDays(90)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
    }
    
    func testReminders_Day89_AllDaysCompleted() {
        let calendar = Calendar(identifier: .iso8601)
        
        var setup: StudySetup = .day89_tasksFinished_noMissingDays
        setup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(setup)
        let studySetup = scheduleManager.studySetup
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check that the scheduled reminder time is decoded correctly
        let scheduledReminderTime = scheduleManager.getReminderTime()
        XCTAssertNotNil(scheduledReminderTime)
        XCTAssertEqual(scheduledReminderTime?.hour, 14)
        XCTAssertEqual(scheduledReminderTime?.minute, 0)
        
        guard let reminderTime = scheduledReminderTime else {
            XCTFail("Failed to get the reminder time. Cannot continue testing.")
            return
        }
        
        let requests = scheduleManager.getLocalNotifications(after: reminderTime, with: [])
        
        // On day 89, with no missed days and today's tasks finished, the schedule should be set up for
        // days 1-19 for the *next* study burst.
        XCTAssertEqual(requests.add.count, 19)
        XCTAssertEqual(requests.removeIds.count, 0)
        if let reminder = requests.add.first?.trigger as? UNCalendarNotificationTrigger,
            let nextDate = calendar.date(from: reminder.dateComponents) {
            let expectedDate = studySetup.createdOn.addingNumberOfDays(90)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
    }
}
