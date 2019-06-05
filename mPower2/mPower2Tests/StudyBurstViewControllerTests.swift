//
//  StudyBurstViewControllerTests.swift
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
import Research

class StudyBurstViewControllerTests: StudyBurstTests {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testTodayVC_Day1_twoTasksFinished() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_twoTasksFinished)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check assumptions
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.hasExpired)
        XCTAssertNotNil(scheduleManager.expiresOn)
        
        // Set the shared study burst manager b/c that's what the vc looks at
        StudyBurstScheduleManager.shared = scheduleManager
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TodayViewController") as! TodayViewController
        let _ = vc.view

        let actionBarTitle = vc.actionBarTitleLabel.text
        let actionBarText = vc.actionBarDetailsLabel.text
        
        XCTAssertEqual(actionBarTitle, "Study Burst")
        XCTAssertEqual(actionBarText, "Progress expires in 15:00")
    }
    
    func testTodayVC_Day1_twoTasksFinished_Now() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day1_twoTasksFinished, now: Date())
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check assumptions
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.hasExpired)
        XCTAssertNotNil(scheduleManager.expiresOn)
        
        // Set the shared study burst manager b/c that's what the vc looks at
        StudyBurstScheduleManager.shared = scheduleManager
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TodayViewController") as! TodayViewController
        let _ = vc.view
        
        let actionBarTitle = vc.actionBarTitleLabel.text
        let actionBarText = vc.actionBarDetailsLabel.text
        
        XCTAssertEqual(actionBarTitle, "Study Burst")
        XCTAssertEqual(actionBarText, "Progress expires in 15:00")
    }
    
    func testTodayVC_Day1_twoTasksFinished_2HoursAgo() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day2_twoFinished_2HoursAgo)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check assumptions
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.hasExpired)
        XCTAssertNotNil(scheduleManager.expiresOn)
        XCTAssertEqual(scheduleManager.totalActivitiesCount, 3)
        XCTAssertEqual(scheduleManager.finishedCount, 2)
        
        // Set the shared study burst manager b/c that's what the vc looks at
        StudyBurstScheduleManager.shared = scheduleManager
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TodayViewController") as! TodayViewController
        let _ = vc.view
        
        let actionBarTitle = vc.actionBarTitleLabel.text
        let actionBarText = vc.actionBarDetailsLabel.text
        
        XCTAssertEqual(actionBarTitle, "Study Burst")
        XCTAssertEqual(actionBarText, "1 ACTIVITY TO DO")
    }
    
    func testTodayVC_Day2_readyToStartTasks() {
        
        let scheduleManager = TestStudyBurstScheduleManager(.day2_readyToStartTasks)
        guard loadSchedules(scheduleManager) else {
            XCTFail("Failed to load the schedules and reports.")
            return
        }
        
        // Check assumptions
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.hasExpired)
        XCTAssertNil(scheduleManager.expiresOn)
        XCTAssertEqual(scheduleManager.totalActivitiesCount, 3)
        XCTAssertEqual(scheduleManager.finishedCount, 0)
        
        // Set the shared study burst manager b/c that's what the vc looks at
        StudyBurstScheduleManager.shared = scheduleManager
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TodayViewController") as! TodayViewController
        let _ = vc.view
        
        let actionBarTitle = vc.actionBarTitleLabel.text
        let actionBarText = vc.actionBarDetailsLabel.text
        
        XCTAssertEqual(actionBarTitle, "Study Burst")
        XCTAssertEqual(actionBarText, "3 ACTIVITIES TO DO")
    }
}
