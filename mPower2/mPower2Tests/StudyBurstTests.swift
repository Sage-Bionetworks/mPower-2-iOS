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
    
    // MARK: Notification rules tests
    
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
