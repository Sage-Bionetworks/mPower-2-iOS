//
//  TodayScheduleManagerTests.swift
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
import Research
@testable import BridgeApp

class TodayScheduleManagerTests: StudyBurstTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTodaySchedule_TriggerCount() {
        
        let activityManager = ActivityManager()
        let startOfDay = Date().startOfDay()

        let run1 = startOfDay.addingTimeInterval(2 * 60 * 60)
        let run1Timestamp = (run1 as NSDate).iso8601String()!
        
        let run2 = startOfDay.addingTimeInterval(4 * 60 * 60)
        let run2Timestamp = (run2 as NSDate).iso8601String()!
        
        let clientData1: NSDictionary =
            [
                "items" : [
                    [
                        "identifier" : "itemA",
                        "loggedDate" : run1Timestamp,
                    ],
                    [
                        "identifier" : "itemB"
                    ]
                ],
                "endDate" : run1Timestamp,
                "startDate" : run1Timestamp,
                "type" : "loggingCollection",
                "identifier" : "logging"
            ]
        
        let clientData2: NSDictionary =
            [
                "items" : [
                    [
                        "identifier" : "itemA",
                        "loggedDate" : run2Timestamp
                        ],
                    [
                        "identifier" : "itemB",
                        "loggedDate" : run2Timestamp
                    ]
                ],
                "endDate" : run2Timestamp,
                "startDate" : run2Timestamp,
                "type" : "loggingCollection",
                "identifier" : "logging"
            ]
        
        let schedule1 = activityManager.createSchedule(with: .triggersTask,
                                           scheduledOn: startOfDay,
                                           expiresOn: nil,
                                           finishedOn: run1,
                                           clientData: nil,
                                           schedulePlanGuid: nil)
        let schedule2 = activityManager.createSchedule(with: .triggersTask,
                                                       scheduledOn: run1.addingTimeInterval(60),
                                                       expiresOn: nil,
                                                       finishedOn: run2,
                                                       clientData: nil,
                                                       schedulePlanGuid: nil)
        
        let scheduleManager = TodayHistoryScheduleManager()
        let scheduledActivities = [schedule1, schedule2]
        
        let report1 = SBAReport(reportKey: .triggersTask,
                                date: run1,
                                clientData: clientData1 as NSDictionary)
        scheduleManager.reports.insert(report1)
        
        let report2 = SBAReport(reportKey: .triggersTask,
                                date: run2,
                                clientData: clientData2 as NSDictionary)
        scheduleManager.reports.insert(report2)
        
        let items = scheduleManager.consolidateItems(scheduledActivities)
        
        XCTAssertEqual(items.count, 1)
        
        guard let triggersItem = items.first else {
            XCTFail("Failed to create triggers item.")
            return
        }
        
        XCTAssertEqual(triggersItem.count, 3)
        XCTAssertEqual(triggersItem.type, .triggers)
    }
    
    func testTodaySchedule_Day1_twoTasksFinished() {
        
        // Use the study burst manager to load all the schedules
        let scheduleManager = TestTodayHistoryScheduleManager(.day1_twoTasksFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        let items = scheduleManager.items
        XCTAssertEqual(items.count, 2)
        guard let firstItem = items.first, let lastItem = items.last else {
            XCTFail("Failed to create expected activites item.")
            return
        }
        
        XCTAssertEqual(firstItem.count, 2)
        XCTAssertEqual(firstItem.type, .activities)
        
        XCTAssertEqual(lastItem.count, 1)
        XCTAssertEqual(lastItem.type, .surveys)
    }
}

class TestTodayHistoryScheduleManager : TodayHistoryScheduleManager, TestScheduleManager {
    
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
    var update_previousActivities:[SBBScheduledActivity]?
    var update_fetchedActivities: [SBBScheduledActivity]?
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
}


