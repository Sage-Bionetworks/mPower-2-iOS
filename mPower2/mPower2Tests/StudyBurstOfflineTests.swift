//
//  StudyBurstOfflineTests.swift
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

class StudyBurstOfflineTests: XCTestCase {

    override func setUp() {
        RSDFactory.shared = MP2Factory()
        StudyBurstScheduleManager.flushDefaults()
    }

    override func tearDown() {
    }
    
    func testDay1_Startup() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day1_startupState)
        
        // This scenario is to test for a new participant who has signed up but does not have
        // loaded schedules. (slow internet, race conditions, etc.) The user should be shown
        // the engagement survey and the initial state should be for Day 1 of the study burst.
        
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        let orderedTasks = scheduleManager.orderedTasks
        XCTAssertEqual(orderedTasks.count, 3)
        
        let todoCount = orderedTasks.reduce(0, { ($1.finishedOn != nil) ? $0 : $0 + 1})
        XCTAssertEqual(todoCount, 3)
    }
    
    func testDay2() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day2_readyToStartTasks)
        
        // This scenario is to test for a new participant who has signed up and completed all of
        // the first-day tasks, but where the launching of the app and display of the study burst
        // happens *before* the schedules are loaded, but *after* the activity manager has cached
        // them via BridgeSDK.
        scheduleManager._activityManager.buildSchedules(with: scheduleManager._participantManager)
        
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        let orderedTasks = scheduleManager.orderedTasks
        XCTAssertEqual(orderedTasks.count, 3)
        
        let todoCount = orderedTasks.reduce(0, { ($1.finishedOn != nil) ? $0 : $0 + 1})
        XCTAssertEqual(todoCount, 3)
    }
    
    func testDay2_TwoTasksFinished() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day2_twoTasksFinished)
        
        // This scenario is to test for a new participant who has signed up and completed all of
        // the first-day tasks, but where the launching of the app and display of the study burst
        // happens *before* the schedules are loaded, but *after* the activity manager has cached
        // them via BridgeSDK.
        scheduleManager._activityManager.buildSchedules(with: scheduleManager._participantManager)
        
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        let orderedTasks = scheduleManager.orderedTasks
        XCTAssertEqual(orderedTasks.count, 3)
        
        let todoCount = orderedTasks.reduce(0, { ($1.finishedOn != nil) ? $0 : $0 + 1})
        XCTAssertEqual(todoCount, 1)
    }
    
    func testDay21() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day21_tasksFinished_noMissingDays)
        
        // This scenario is to test for a new participant who has signed up and completed the first
        // full study burst, but where the launching of the app and display of the study burst
        // (or not displaying in this case) happens *before* the schedules are loaded, but *after*
        // the activity manager has cached them via BridgeSDK.
        scheduleManager._activityManager.buildSchedules(with: scheduleManager._participantManager)
        
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 20)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask, "scheduleManager.engagementTaskViewModel()")
    }
}

class OfflineStudyBurstScheduleManager : StudyBurstScheduleManager {
    
    init(_ studySetup: StudySetup, now: Date? = nil, taskOrderTimestamp: Date? = referenceDate) {
        self._now = now ?? Date().addingNumberOfDays(-1).startOfDay().addingTimeInterval(11 * 60 * 60)
        super.init()
        
        // Default to "now" of 11:00 AM yesterday.
        var setup = studySetup
        setup.now = self._now
        setup.taskOrderTimestamp = (taskOrderTimestamp == referenceDate) ? setup.now : taskOrderTimestamp
        
        UserDefaults.standard.set(self._now.addingNumberOfDays(-1 * Int(setup.studyBurstDay)), forKey: StudyBurstScheduleManager.day1StudyBurstKey)
        
        // build the schedules.
        self._activityManager.studySetup = setup
        self._activityManager.participantManager = self._participantManager
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
