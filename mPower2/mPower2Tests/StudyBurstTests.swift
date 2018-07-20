//
//  StudyBurstTests.swift
//  mPower2Tests
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

import XCTest
@testable import mPower2TestApp
@testable import BridgeApp
import Research
import UserNotifications

class StudyBurstTests: XCTestCase {
    
    override func setUp() {
        super.setUp()

        RSDFactory.shared = MP2Factory()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStudyBurstNavigator_Codable() {
        let json = """
        {
            "identifier": "foo",
            "type": "studyBurst",
            "numberOfDays": 12,
            "minimumRequiredDays": 10,
            "expiresLimit": 120,
            "taskGroupIdentifier": "GroupTwo",
            "completionTasks": [
                { "day": 0, "firstOnly": true, "activityIdentifiers" : ["boo", "goo"] },
                { "day": 12, "firstOnly": true, "activityIdentifiers" : ["coo"] }
            ]
        }
        """.data(using: .utf8)! // our data in native (JSON) format
        
        let decoder = RSDFactory.shared.createJSONDecoder()
        
        do {
            let object = try decoder.decode(StudyBurstConfiguration.self, from: json)
            
            XCTAssertEqual(object.identifier, "foo")
            XCTAssertEqual(object.numberOfDays, 12)
            XCTAssertEqual(object.expiresLimit, 120)
            XCTAssertEqual(object.minimumRequiredDays, 10)
            XCTAssertEqual(object.taskGroupIdentifier, "GroupTwo")
            XCTAssertEqual(object.completionTasks.count, 2)
            
        } catch let err {
            XCTFail("Failed to decode/encode object: \(err)")
            return
        }
    }
    
    func testStudyBurstComplete_Day1() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_tasksFinished_demographicsNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveySchedules.count, 0)
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        
        let demographics = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.demographics.stringValue
        }
        XCTAssertEqual(demographics.count, 1)
        
        let studyBurstReminder = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.studyBurstReminder.stringValue
        }
        XCTAssertEqual(studyBurstReminder.count, 1)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Health Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "4 Minutes")
    }
    
    func testStudyBurstComplete_Day1_SurveysFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_tasksFinished_surveysFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveySchedules.count, 0)
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        
        let demographics = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.demographics.stringValue
        }
        XCTAssertEqual(demographics.count, 1)
        
        let studyBurstReminder = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.studyBurstReminder.stringValue
        }
        XCTAssertEqual(studyBurstReminder.count, 1)
        
        XCTAssertNil(scheduleManager.actionBarItem)
    }
    
    func testStudyBurstComplete_Day2_DemographicsNotFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day2_demographicsNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 0)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveySchedules.count, 2)
        XCTAssertNil(scheduleManager.todayCompletionTask)

        if let demographics = scheduleManager.scheduledActivities.first(where: {
            $0.activityIdentifier == RSDIdentifier.demographics.stringValue
        }) {
            XCTAssertFalse(demographics.isCompleted)
        }
        else {
            XCTFail("Failed to find the survey.")
        }
        
        let studyBurstReminder = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.studyBurstReminder.stringValue
        }
        XCTAssertEqual(studyBurstReminder.count, 1)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Health Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "4 Minutes")
    }
    
    func testStudyBurstComplete_Day15_Missing1() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day15_missing1_engagementNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurstComplete_Day14_Missing1() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day14_missing1_tasksFinished_engagementNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 14)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertTrue(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurstComplete_Day14_Missing6() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day14_missing6_tasksFinished_engagementNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 14)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNil(completionTask)
    }
    
    func testStudyBurstComplete_Day21_Missing6() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day21_missing6_engagementNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurstComplete_Day15_BurstComplete_EngagementNotComplete() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day15_burstCompleted_engagementNotFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurstComplete_Day15_BurstComplete_EngagementComplete() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day15_burstCompleted_engagementFinished)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNil(completionTask)
        
        XCTAssertNil(scheduleManager.actionBarItem)
    }
    
    // MARK: Notification rules tests
    
    func testReminders_Day1() {
        let calendar = Calendar(identifier: .iso8601)

        var studySetup: StudySetup = .day1_tasksFinished_surveysFinished
        studySetup.reminderTime = "09:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(studySetup)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
        // Test assumptions
        let reminderSchedule = scheduleManager._activityManager.schedules.first(where: {
            $0.activityIdentifier == RSDIdentifier.studyBurstReminder.stringValue  })
        XCTAssertNotNil(reminderSchedule)
        XCTAssertNotNil(reminderSchedule?.clientData)
        
        let studyBurstReminder = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.studyBurstReminder.stringValue
        }
        XCTAssertEqual(studyBurstReminder.count, 1)
        
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
        
        var studySetup: StudySetup = .day2_tasksNotFinished_surveysFinished
        studySetup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(studySetup)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
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
            let nextDate = reminder.nextTriggerDate() {
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
        
        var studySetup: StudySetup = .day11_tasksFinished_noMissingDays
        studySetup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(studySetup)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
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
            let nextDate = reminder.nextTriggerDate() {
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
            let nextDate = reminder.nextTriggerDate() {
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
        
        var studySetup: StudySetup = .day21_tasksFinished_noMissingDays
        studySetup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(studySetup)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
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
            let nextDate = reminder.nextTriggerDate() {
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
        
        var studySetup: StudySetup = .day89_tasksFinished_noMissingDays
        studySetup.reminderTime = "14:00:00"
        let scheduleManager = TestStudyBurstScheduleManager(studySetup)
        XCTAssertTrue(loadSchedules(scheduleManager))
        
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
            let nextDate = reminder.nextTriggerDate() {
            let expectedDate = studySetup.createdOn.addingNumberOfDays(90)
            XCTAssertFalse(reminder.repeats)
            XCTAssertTrue(calendar.isDate(nextDate, inSameDayAs: expectedDate), "\(nextDate) is not in same day as \(expectedDate)")
            XCTAssertEqual(reminder.dateComponents.hour, 14)
        }
        else {
            XCTFail("\(String(describing: requests.add.first?.trigger)) nil or not of expected type")
        }
    }
    
    
    // MARK: helper methods
    
    func loadSchedules(_ scheduleManager: TestStudyBurstScheduleManager) -> Bool {
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        var success: Bool = true
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
            success = (err == nil)
        }
        return success
    }
}

class TestStudyBurstScheduleManager : StudyBurstScheduleManager {
    
    init(_ studySetup: StudySetup, now: Date? = nil) {
        super.init()
        
        // Default to "now" of 11:00 AM.
        var setup = studySetup
        setup.now = now ?? Date().startOfDay().addingTimeInterval(11 * 60 * 60)
        
        // build the schedules.
        self._activityManager.studySetup = setup
        self._activityManager.buildSchedules()
    }
    
    let _activityManager = ActivityManager()
    
    override func now() -> Date {
        return self._activityManager.studySetup.now
    }
    
    override var activityManager: SBBActivityManagerProtocol {
        return _activityManager
    }
    
    var updateFinishedBlock: (() -> Void)?
    var updateFailed_error: Error?
    var update_fetchedActivities:[SBBScheduledActivity]?
    var sendUpdated_schedules: [SBBScheduledActivity]?
    var sendUpdated_taskPath: RSDTaskPath?
    
    override func updateFailed(_ error: Error) {
        updateFailed_error = error
        super.updateFailed(error)
        updateFinishedBlock?()
        updateFinishedBlock = nil
    }
    
    override func update(fetchedActivities: [SBBScheduledActivity]) {
        update_fetchedActivities = fetchedActivities
        super.update(fetchedActivities: fetchedActivities)
        updateFinishedBlock?()
        updateFinishedBlock = nil
    }
}


