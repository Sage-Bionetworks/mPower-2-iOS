//
//  StudyBurstTests.swift
//  mPower2Tests
//
//  Copyright © 2018-2019 Sage Bionetworks. All rights reserved.
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

class StudyBurstManagerTests: StudyBurstTests {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
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
            "motivationIdentifier": "Motivation",
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
    
    func testStudyBurst_Day1_StartState() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_startupState)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        
        let orderedTasks = scheduleManager.orderedTasks
        let noneFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn == nil) })
        XCTAssertTrue(noneFinished)
        
        let demographics = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.demographics.stringValue
        }
        XCTAssertEqual(demographics.count, 1)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        XCTAssertNil(scheduleManager.actionBarItem, "scheduleManager.actionBarItem")
        
        let thisDay = scheduleManager.calculateThisDay()
        XCTAssertEqual(thisDay, 1)
        
        let pastTasks = scheduleManager.getPastTasks(for: thisDay)
        XCTAssertEqual(pastTasks.count, 0)
        
        XCTAssertNotNil(scheduleManager.todayCompletionTask, "scheduleManager.todayCompletionTask")
        let todayCompletionTask = scheduleManager.getTodayCompletionTask(for: thisDay)
        XCTAssertNotNil(todayCompletionTask, "scheduleManager.getTodayCompletionTask(for: thisDay)")
        
        let unfinishedSchedule = scheduleManager.getUnfinishedSchedule()
        XCTAssertNil(unfinishedSchedule, "scheduleManager.getUnfinishedSchedule(from: pastTasks)")
    }
    
    func testStudyBurst_Day1() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_tasksFinished_surveysNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        
        let orderedTasks = scheduleManager.orderedTasks
        let allFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn != nil) })
        XCTAssertTrue(allFinished)
        
        let demographics = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.demographics.stringValue
        }
        XCTAssertEqual(demographics.count, 1)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 2)
            XCTAssertEqual(steps.first?.identifier, "StudyBurstReminder")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem, "scheduleManager.actionBarItem")
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Health Survey")
    
        let thisDay = scheduleManager.calculateThisDay()
        XCTAssertEqual(thisDay, 1)
        
        let pastTasks = scheduleManager.getPastTasks(for: thisDay)
        XCTAssertEqual(pastTasks.count, 0)
        
        XCTAssertNotNil(scheduleManager.todayCompletionTask, "scheduleManager.todayCompletionTask")
        let todayCompletionTask = scheduleManager.getTodayCompletionTask(for: thisDay)
        XCTAssertNotNil(todayCompletionTask, "scheduleManager.getTodayCompletionTask(for: thisDay)")
        
        let unfinishedSchedule = scheduleManager.getUnfinishedSchedule()
        XCTAssertNotNil(unfinishedSchedule, "scheduleManager.getUnfinishedSchedule(from: pastTasks)")
        
        let today = scheduleManager._now
        let studyBurstMarkerId = RSDIdentifier.studyBurstCompletedTask.stringValue
        guard
            let schedules = scheduleManager.sendUpdated_schedules,
            let studyMarker = schedules.first(where: {
                $0.activityIdentifier == studyBurstMarkerId &&
                    Calendar.current.isDate($0.scheduledOn, inSameDayAs: today) })
            else {
                XCTFail("Expected the study burst marker to be sent")
                return
        }
        
        guard let clientData = studyMarker.clientData as? [String : String]
            else {
                XCTFail("Expected study marker to include client data")
                return
        }
        
        XCTAssertEqual(clientData["taskOrder"], "Tapping,Tremor,WalkAndBalance")
        XCTAssertNotNil(clientData["Tapping.startDate"])
        XCTAssertNotNil(clientData["WalkAndBalance.startDate"])
        XCTAssertNotNil(clientData["Tremor.startDate"])
        XCTAssertNotNil(clientData["WalkAndBalance.endDate"])
        XCTAssertNotNil(clientData["Tremor.endDate"])
        XCTAssertNotNil(clientData["Tapping.endDate"])
        XCTAssertNotNil(clientData["WalkAndBalance.scheduleGuid"])
        XCTAssertNotNil(clientData["Tapping.scheduleGuid"])
        XCTAssertNotNil(clientData["Tremor.scheduleGuid"])
    }
    
    func testStudyBurst_Day1_twoTasksFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_twoTasksFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        XCTAssertFalse(scheduleManager.isFinalTask(RSDIdentifier.tappingTask.stringValue))
        XCTAssertTrue(scheduleManager.isFinalTask(RSDIdentifier.tremorTask.stringValue))
        
        let orderedTasks = scheduleManager.orderedTasks
        let expectedIds: [RSDIdentifier] = [.walkAndBalanceTask, .tappingTask, .tremorTask]
        XCTAssertEqual(orderedTasks.map { $0.identifier }, expectedIds.map { $0.stringValue })
        
        guard orderedTasks.count == expectedIds.count else {
            XCTFail("Failed to get expected count for the ordered tasks")
            return
        }
        
        XCTAssertNotNil(orderedTasks[0].finishedOn)
        let completedFirst = scheduleManager.isCompleted(for: orderedTasks[0].taskInfo, on: scheduleManager._now)
        XCTAssertTrue(completedFirst)
        XCTAssertNotNil(orderedTasks[1].finishedOn)
        let completedSecond = scheduleManager.isCompleted(for: orderedTasks[1].taskInfo, on: scheduleManager._now)
        XCTAssertTrue(completedSecond)
        XCTAssertNil(orderedTasks[2].finishedOn)
        let completedLast = scheduleManager.isCompleted(for: orderedTasks[2].taskInfo, on: scheduleManager._now)
        XCTAssertFalse(completedLast)

        guard let expiresOn = scheduleManager.expiresOn,
            let earliestFinishedOn = orderedTasks.first?.finishedOn
            else {
                XCTFail("Failed to get expires on and earliest schedule.")
                return
        }
        
        let expectedExpiresOn = earliestFinishedOn.addingTimeInterval(60 * 60)
        XCTAssertEqual(expectedExpiresOn, expiresOn)
    }
    
    func testStudyBurst_Day2_twoTasksFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day2_twoTasksFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let orderedTasks = scheduleManager.orderedTasks
        let expectedIds: [RSDIdentifier] = [.tappingTask, .tremorTask, .walkAndBalanceTask]
        XCTAssertEqual(orderedTasks.map { $0.identifier }, expectedIds.map { $0.stringValue })
        
        guard orderedTasks.count == expectedIds.count else {
            XCTFail("Failed to get expected count for the ordered tasks")
            return
        }
        
        XCTAssertNotNil(orderedTasks[0].finishedOn)
        let completedFirst = scheduleManager.isCompleted(for: orderedTasks[0].taskInfo, on: scheduleManager._now)
        XCTAssertTrue(completedFirst)
        XCTAssertNotNil(orderedTasks[1].finishedOn)
        let completedSecond = scheduleManager.isCompleted(for: orderedTasks[1].taskInfo, on: scheduleManager._now)
        XCTAssertTrue(completedSecond)
        XCTAssertNil(orderedTasks[2].finishedOn)
        let completedLast = scheduleManager.isCompleted(for: orderedTasks[2].taskInfo, on: scheduleManager._now)
        XCTAssertFalse(completedLast)
        
        guard let expiresOn = scheduleManager.expiresOn,
            let earliestFinishedOn = orderedTasks.first?.finishedOn
            else {
                XCTFail("Failed to get expires on and earliest schedule.")
                return
        }
        
        let expectedExpiresOn = earliestFinishedOn.addingTimeInterval(60 * 60)
        XCTAssertEqual(expectedExpiresOn, expiresOn)
    }
    
    func testStudyBurst_Day2_twoTasksFinished_2HoursAgo() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day2_twoFinished_2HoursAgo)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let orderedTasks = scheduleManager.orderedTasks
        let expectedIds: [RSDIdentifier] = [.walkAndBalanceTask, .tappingTask, .tremorTask]
        XCTAssertEqual(orderedTasks.map { $0.identifier }, expectedIds.map { $0.stringValue })
        
        guard orderedTasks.count == expectedIds.count else {
            XCTFail("Failed to get expected count for the ordered tasks")
            return
        }
        
        XCTAssertNotNil(orderedTasks[0].finishedOn)
        let completedFirst = scheduleManager.isCompleted(for: orderedTasks[0].taskInfo, on: scheduleManager._now)
        XCTAssertTrue(completedFirst)
        XCTAssertNotNil(orderedTasks[1].finishedOn)
        let completedSecond = scheduleManager.isCompleted(for: orderedTasks[1].taskInfo, on: scheduleManager._now)
        XCTAssertTrue(completedSecond)
        XCTAssertNil(orderedTasks[2].finishedOn)
        let completedLast = scheduleManager.isCompleted(for: orderedTasks[2].taskInfo, on: scheduleManager._now)
        XCTAssertFalse(completedLast)
        
        guard let expiresOn = scheduleManager.expiresOn,
            let earliestFinishedOn = orderedTasks.first?.finishedOn
            else {
                XCTFail("Failed to get expires on and earliest schedule.")
                return
        }
        
        let expectedExpiresOn = earliestFinishedOn.addingTimeInterval(60 * 60)
        XCTAssertEqual(expectedExpiresOn, expiresOn)
        
        // finish the last task and check if all within limit
        scheduleManager.orderedTasks.last!.startedOn = scheduleManager._now.addingTimeInterval(-2 * 60)
        scheduleManager.orderedTasks.last!.finishedOn = scheduleManager._now
        XCTAssertFalse(scheduleManager.finishedWithinLimit)
    }
    
    func testStudyBurst_Day1_SurveysFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_tasksFinished_surveysFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        
        let orderedTasks = scheduleManager.orderedTasks
        let allFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn != nil) })
        XCTAssertTrue(allFinished)
        
        let demographics = scheduleManager.scheduledActivities.filter {
            $0.activityIdentifier == RSDIdentifier.demographics.stringValue
        }
        XCTAssertEqual(demographics.count, 1)
        
        XCTAssertNil(scheduleManager.actionBarItem)
    }
    
    func testStudyBurst_Day2_Day1SurveysNotFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day2_surveysNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertNil(scheduleManager.todayCompletionTask)
        
        let orderedTasks = scheduleManager.orderedTasks
        let noneFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn == nil) })
        XCTAssertTrue(noneFinished)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask)
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 2)
            XCTAssertEqual(steps.first?.identifier, "StudyBurstReminder")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
    }
    
    func testStudyBurst_Day15_Missing1() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day15_missing1_engagementNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask)
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 1)
            XCTAssertEqual(steps.first?.identifier, "Engagement")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurst_Day14_Missing1() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day14_missing1_tasksFinished_engagementNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 14)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertTrue(scheduleManager.isLastDay)
        
        let orderedTasks = scheduleManager.orderedTasks
        let allFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn != nil) })
        XCTAssertTrue(allFinished)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask)
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 1)
            XCTAssertEqual(steps.first?.identifier, "Engagement")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurst_Day14_Missing6() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day14_missing6_tasksFinished_engagementNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 14)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let orderedTasks = scheduleManager.orderedTasks
        let allFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn != nil) })
        XCTAssertTrue(allFinished)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask)
    }
    
    func testStudyBurst_Day9_TasksFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day9_tasksFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 9)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertTrue(scheduleManager.isFinalTask(RSDIdentifier.walkAndBalanceTask.stringValue))
        
        let orderedTasks = scheduleManager.orderedTasks
        let allFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn != nil) })
        XCTAssertTrue(allFinished)
        
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask)
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 1)
            XCTAssertEqual(steps.first?.identifier, "Background")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
    }
    
    func testStudyBurst_Day21_Missing6() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day21_missing6_engagementNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask)
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 1)
            XCTAssertEqual(steps.first?.identifier, "Engagement")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurst_Day15_BurstComplete_EngagementNotComplete() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day15_burstCompleted_engagementNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask)
        
        if let steps = (completionTask?.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps {
            XCTAssertEqual(steps.count, 1)
            XCTAssertEqual(steps.first?.identifier, "Engagement")
        }
        else {
            XCTFail("Failed to get the expected navigator for the completion task")
        }
        
        XCTAssertNotNil(scheduleManager.actionBarItem)
        XCTAssertEqual(scheduleManager.actionBarItem?.title, "Engagement Survey")
        XCTAssertEqual(scheduleManager.actionBarItem?.detail, "6 Minutes")
    }
    
    func testStudyBurst_Day15_BurstComplete_EngagementComplete() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day15_burstCompleted_engagementFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask)
        
        XCTAssertNil(scheduleManager.actionBarItem)
    }
    
    func testStudyBurst_Day1_AllFinished_2HoursAgo() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_allFinished_2HoursAgo)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        XCTAssertNotNil(scheduleManager.todayCompletionTask)
        XCTAssertNil(scheduleManager.actionBarItem)
        
        let orderedTasks = scheduleManager.orderedTasks
        let allFinished = orderedTasks.reduce(true, { $0 && ($1.finishedOn != nil) })
        XCTAssertTrue(allFinished)
        
        XCTAssertTrue(scheduleManager.finishedWithinLimit)
    }
    
    func testDay1_ClientData() {
        let scheduleManager = TestStudyBurstScheduleManager(.day1_tasksFinished_surveysNotFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }

        guard let completionTask = scheduleManager.engagementTaskViewModel(),
            let steps = (completionTask.task?.stepNavigator as? RSDConditionalStepNavigator)?.steps,
            steps.count == 2
            else {
                XCTFail("Failed to get the expected navigator for the completion task")
                return
        }
        
        var taskResult = RSDTaskResultObject(identifier: completionTask.identifier, schemaInfo: nil)
        
        // Add study burst
        var reminderTaskResult = RSDTaskResultObject(identifier: "StudyBurstReminder", schemaInfo: nil)
        var reminderResult = RSDCollectionResultObject(identifier: "reminder")
        let reminderTimeResultType = RSDAnswerResultType(baseType: .date, sequenceType: nil, formDataType: nil, dateFormat: "HH:mm:ss", unit: nil, sequenceSeparator: nil)
        let reminderTime = Date()
        reminderResult.appendInputResults(with: RSDAnswerResultObject(identifier: "reminderTime", answerType: reminderTimeResultType, value: reminderTime))
        reminderResult.appendInputResults(with: RSDAnswerResultObject(identifier: "noReminder", answerType: .boolean, value: false))
        reminderTaskResult.appendStepHistory(with: reminderResult)
        taskResult.appendStepHistory(with: reminderTaskResult)
        
        guard let reports = scheduleManager.buildReports(from: taskResult),
            let report = reports.first
            else {
                XCTFail("Failed to build the expected reports")
                return
        }
    
        XCTAssertEqual(report.identifier, "StudyBurstReminder")
        XCTAssertEqual(report.date, SBAReportSingletonDate)
        if let clientData = report.clientData as? [String : Any] {
            XCTAssertEqual(clientData["noReminder"] as? Int, 0)
            XCTAssertNotNil(clientData["reminderTime"] as? String)
        }
        else {
            XCTFail("Clientdata does not match expected format. \(report.clientData)")
        }

        // TODO: syoung 05/07/2019 There isn't a straight-forward way of checking the demographics survey
        // because that is vended from the server and thus setting up the test means using expectations and
        // timeouts or else creating the SBBSurvey object from the JSON dictionary.
    }
    
    func testRandomShuffleTasks() {
        
        let now = Date().addingNumberOfDays(-3).startOfDay().addingTimeInterval(11 * 60 * 60)
        let scheduleManager = TestStudyBurstScheduleManager(.day2_twoTasksFinished, now: now)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Run method under test
        let orderedTasks = scheduleManager.orderedTasks
        let taskIdentifiers = orderedTasks.map { $0.identifier }
        
        let updatedTimestamp = UserDefaults.standard.object(forKey: StudyBurstScheduleManager.timestampKey) as? Date
        let updatedStoredOrder = UserDefaults.standard.array(forKey: StudyBurstScheduleManager.orderKey) as? [String]
    
        XCTAssertEqual(taskIdentifiers, updatedStoredOrder)
        XCTAssertEqual(updatedTimestamp, now)
        
        XCTAssertFalse(scheduleManager.shouldRefreshTasks)
     
        // Check that calling again returns the same values
        let secondCall = scheduleManager.orderedTasks.map { $0.identifier }
        XCTAssertEqual(taskIdentifiers, secondCall)
        
        // Set up the study burst for background for a day and check again
        scheduleManager._now = now.addingNumberOfDays(1)
        
        XCTAssertTrue(scheduleManager.shouldRefreshTasks)
        
        let newDayTasks = scheduleManager.orderedTasks
        let newDayTaskIds = newDayTasks.map { $0.identifier }
        newDayTasks.forEach {
            XCTAssertNil($0.finishedOn)
            XCTAssertNil($0.startedOn)
        }
        
        let newDayTimestamp = UserDefaults.standard.object(forKey: StudyBurstScheduleManager.timestampKey) as? Date
        let newDayStoredOrder = UserDefaults.standard.array(forKey: StudyBurstScheduleManager.orderKey) as? [String]
        
        XCTAssertEqual(newDayTimestamp, scheduleManager._now)
        XCTAssertNotEqual(newDayTimestamp, now)
        XCTAssertEqual(newDayStoredOrder, newDayTaskIds)
    }
    
    func testRandomGroups() {
        let groups: [Set<String>] = Array(1...1000).map { _ in StudyBurstConfiguration().randomEngagementGroups()! }
        let unique = Set(groups)
        XCTAssertGreaterThan(unique.count, 1)
        XCTAssertEqual(unique.count, 16)
    }
}

class StudyBurstTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        RSDFactory.shared = MP2Factory()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: helper method
    
    func loadSchedules(_ scheduleManager: TestScheduleManager) -> Bool {
        
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
        guard success else { return false }
        
        let expectReports = expectation(description: "Update finished called.")
        scheduleManager.finishedFetchingReportsBlock = {
            expectReports.fulfill()
        }
        scheduleManager.loadReports()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
            success = (err == nil)
        }

        return success
    }
}

protocol TestScheduleManager : class {
    var updateFinishedBlock: (() -> Void)? { get set }
    var finishedFetchingReportsBlock: (() -> Void)?  { get set }
    
    func loadReports()
    func loadScheduledActivities()
}

let referenceDate = Date(timeIntervalSince1970: 0)

class TestStudyBurstScheduleManager : StudyBurstScheduleManager, TestScheduleManager {
    
    init(_ studySetup: StudySetup, now: Date? = nil, taskOrderTimestamp: Date? = referenceDate) {
        self._now = now ?? Date().addingNumberOfDays(-1).startOfDay().addingTimeInterval(11 * 60 * 60)
        super.init()
        
        // Default to "now" of 11:00 AM yesterday.
        var setup = studySetup
        setup.now = self._now
        setup.taskOrderTimestamp = (taskOrderTimestamp == referenceDate) ? setup.now : taskOrderTimestamp
        
        // build the schedules.
        self._activityManager.studySetup = setup
        self._activityManager.buildSchedules(with: self._participantManager)
        self._participantManager.setup(with: setup)
    }
    
    let _activityManager = ActivityManager()
    let _participantManager = ParticipantManager()
    var _now: Date
    
    var studySetup: StudySetup {
        return self._activityManager.studySetup
    }
    
    override func now() -> Date {
        return _now
    }
    
    override func today() -> Date {
        return _now
    }
    
    override var activityManager: SBBActivityManagerProtocol {
        return _activityManager
    }
    
    override var participantManager: SBBParticipantManagerProtocol {
        return _participantManager
    }
    
    var updateFinishedBlock: (() -> Void)?
    var updateFailed_error: Error?
    var update_previousActivities: [SBBScheduledActivity]?
    var update_fetchedActivities: [SBBScheduledActivity]?
    var didUpdateScheduledActivities_called: Bool = false
    var sendUpdated_schedules: [SBBScheduledActivity]?
    var sendUpdated_taskPath: RSDTaskViewModel?
    
    var finishedFetchingReportsBlock: (() -> Void)?
    
    override func updateFailed(_ error: Error) {
        updateFailed_error = error
        super.updateFailed(error)
        updateFinishedBlock?()
        updateFinishedBlock = nil
    }
    
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        update_previousActivities = previousActivities
        update_fetchedActivities = self.scheduledActivities
        super.didUpdateScheduledActivities(from: previousActivities)
        updateFinishedBlock?()
        updateFinishedBlock = nil
    }
    
    override func didFinishFetchingReports() {
        finishedFetchingReportsBlock?()
        finishedFetchingReportsBlock = nil
    }
    
    override func sendUpdated(for schedules: [SBBScheduledActivity], taskViewModel: RSDTaskViewModel? = nil) {
        self.sendUpdated_schedules = schedules
        self.sendUpdated_taskPath = taskViewModel
        super.sendUpdated(for: schedules, taskViewModel: taskViewModel)
    }
}
