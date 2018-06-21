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
    
    func testStudyBurstComplete_DayOne() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 0
        studySetup.studyBurstFinishedOnDays = []
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
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
    }
    
    func testStudyBurstComplete_Day15_MissingOne() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 14
        var finishedDays: [Int] = Array(0...13)
        finishedDays.remove(at: 2)
        studySetup.studyBurstFinishedOnDays = finishedDays
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 15)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertTrue(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
    }
    
    func testStudyBurstComplete_Day15_MissingTwo() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 14
        var finishedDays: [Int] = Array(0...13)
        finishedDays.remove(at: 2)
        finishedDays.remove(at: 4)
        studySetup.studyBurstFinishedOnDays = finishedDays
        studySetup.studyBurstSurveyFinishedOnDays = [.demographics : 0, .studyBurstReminder : 0]
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 15)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNil(completionTask)
    }
    
    func testStudyBurstComplete_Day14_MissingOne() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 13
        var finishedDays: [Int] = Array(0...13)
        finishedDays.remove(at: 2)
        studySetup.studyBurstFinishedOnDays = finishedDays
        studySetup.studyBurstSurveyFinishedOnDays = [.demographics : 0, .studyBurstReminder : 0]
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
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
    
    func testStudyBurstComplete_Day2_NoDemographics() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 1
        let finishedDays: [Int] = Array(0...1)
        studySetup.studyBurstFinishedOnDays = finishedDays
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertEqual(scheduleManager.finishedSchedules.count, 3)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
    }
    
    func testStudyBurstComplete_Day15_BurstComplete_EngagementNotComplete() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 14
        let finishedDays: [Int] = Array(0...13)
        studySetup.studyBurstFinishedOnDays = finishedDays
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
    }
    
    func testStudyBurstComplete_Day15_BurstComplete_EngagementComplete() {
        
        let scheduleManager = TestStudyBurstScheduleManager()
        var studySetup = StudySetup()
        studySetup.studyBurstDay = 14
        let finishedDays: [Int] = Array(0...13)
        studySetup.studyBurstFinishedOnDays = finishedDays
        studySetup.finishedTodayTasks = scheduleManager.activityGroup?.activityIdentifiers ?? []
        scheduleManager._activityManager.studySetup = studySetup
        scheduleManager._activityManager.buildSchedules()
        
        let expect = expectation(description: "Update finished called.")
        scheduleManager.updateFinishedBlock = {
            expect.fulfill()
        }
        scheduleManager.loadScheduledActivities()
        waitForExpectations(timeout: 2) { (err) in
            print(String(describing: err))
        }
        
        XCTAssertNil(scheduleManager.updateFailed_error)
        XCTAssertNotNil(scheduleManager.update_fetchedActivities)
        XCTAssertNotNil(scheduleManager.activityGroup)
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        
        let completionTask = scheduleManager.completionTaskPath()
        XCTAssertNotNil(completionTask)
    }
}

class TestStudyBurstScheduleManager : StudyBurstScheduleManager {
    
    var _activityManager = ActivityManager()
    
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


