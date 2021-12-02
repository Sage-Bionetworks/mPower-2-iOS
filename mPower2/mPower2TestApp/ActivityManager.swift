//
//  ActivityManager.swift
//  mPower2TestApp
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
import BridgeSDK
import BridgeApp
import ResearchV2

public struct StudySetup {
    
    init(_ studyBurstIndex: Int = 0,
         studyBurstDay: UInt = 3,
         studyBurstFinishedOnDays: [Int] = [0, 2],
         studyBurstSurveyFinishedOnDays: [RSDIdentifier : Int] = [:],
         finishedTodayTasks: [RSDIdentifier] = [.tappingTask, .walkAndBalanceTask],
         timeUntilExpires: TimeInterval = 15 * 60,
         dataGroups: [String] = ["gr_SC_DB","gr_BR_II","gr_ST_T","gr_DT_T"],
         heartSnapshotCompletedDaysAgo: Int = 0) {
        
        self.studyBurstDay = studyBurstDay
        self.studyBurstFinishedOnDays = studyBurstFinishedOnDays
        self.studyBurstSurveyFinishedOnDays = studyBurstSurveyFinishedOnDays
        self.finishedTodayTasks = finishedTodayTasks
        self.timeUntilExpires = timeUntilExpires
        self.dataGroups = dataGroups
        self.studyBurstIndex = studyBurstIndex
        self.heartSnapshotCompletedDaysAgo = heartSnapshotCompletedDaysAgo
    }
    
    /// First name of the participant.
    var firstName = "Rumplestiltskin"
    
    /// The count for the study bursts. Assumed that if > 0, that the previous study burst was
    /// completed and the engagement survey was taken.
    let studyBurstIndex: Int

    /// Study Burst "day" where Day 0 is the day the participant was "created".
    let studyBurstDay: UInt
    
    /// The days in the past when the particpant finished all the tasks.
    let studyBurstFinishedOnDays: [Int]
    
    /// The days when the study burst was finished.
    let studyBurstSurveyFinishedOnDays: [RSDIdentifier : Int]
    
    /// A list of the tasks to mark as finished today for a study burst. If included, this will be used to
    /// define the order of the tasks for display in the study burst view.
    let finishedTodayTasks: [RSDIdentifier]
    
    /// The time to use as the time until today's finished tasks will expire. Default = 15 min.
    var timeUntilExpires: TimeInterval
    
    /// The data groups to set for this participant.
    var dataGroups: [String]
    
    /// The time to set as "now".
    var now: Date = Date()
    
    /// The sudy burst reminders
    var reminderTime: String?
    
    /// Should the task order be set up for this test?
    var taskOrderTimestamp: Date? = Date()
    
    /// The number of days ago that the heart snapshot was completed
    var heartSnapshotCompletedDaysAgo: Int
    
    /// First day of the current study burst.
    var studyBurstDayOne: Date {
        return now.startOfDay().addingNumberOfDays(-1 * Int(studyBurstDay))
    }
    
    /// The date when the participant started the study. Hardcoded to 6:15AM local time.
    var createdOn: Date {
        let dayOne = studyBurstDayOne
        let createdOn = Calendar.iso8601.date(byAdding: .month, value: -3 * self.studyBurstIndex, to: dayOne)!.addingTimeInterval(6.25 * 60 * 60)
        return createdOn
    }
    
    var finishedMotivation: Bool {
        return self.finishedTodayTasks.count > 0 || self.studyBurstFinishedOnDays.count > 0
    }
    
    /// Generated days of the study burst to mark as finished. This only applies to days that are past.
    func mapStudyBurstFinishedOn() -> [Int : Date] {
        let firstDay = createdOn.startOfDay().addingTimeInterval(8 * 60 * 60)
        return studyBurstFinishedOnDays.reduce(into: [Int : Date]()) { (hashtable, day) in
            guard day <= self.studyBurstDay else { return }
            let time = TimeInterval(arc4random_uniform(30 * 60))
            let timestamp = firstDay.addingNumberOfDays(day).addingTimeInterval(time)
            hashtable[day] = timestamp
        }
    }
    
    /// Generated days of the study burst to mark as finished. This only applies to days that are past.
    func mapStudyBurstSurveyFinishedOn() -> [RSDIdentifier : Date] {
        let firstDay = createdOn.startOfDay().addingTimeInterval(8.5 * 60 * 60)
        var map = studyBurstSurveyFinishedOnDays.reduce(into: [RSDIdentifier : Date]()) { (hashtable, input) in
            let day = input.value
            guard day <= self.studyBurstDay else { return }
            let time = TimeInterval(arc4random_uniform(30 * 60))
            let timestamp = firstDay.addingNumberOfDays(day).addingTimeInterval(time)
            hashtable[input.key] = timestamp
        }
        if self.finishedMotivation {
            map[.motivation] = firstDay.addingTimeInterval(2 * 60)
        }
        return map
    }
    
    func createParticipant() -> SBBStudyParticipant {
        return SBBStudyParticipant(dictionaryRepresentation: [
            "createdOn" : (createdOn as NSDate).iso8601String()!,
            "dataGroups" : dataGroups,
            "firstName" : firstName,
            "phoneVerified" : NSNumber(value: true),
            ])!
    }
}

extension StudySetup {
    
    static func finishedOnDays(_ studyBurstDay: Int, _ missingCount: Int) -> [Int] {
        if studyBurstDay == missingCount {
            return []
        }
        var finishedDays: IndexSet = IndexSet(Array(0..<studyBurstDay))    
        if missingCount > 0 {
            let offset = finishedDays.count / (missingCount + 1)
            for ii in 0..<missingCount {
                finishedDays.remove(offset * (ii + 1))
            }
        }
        return Array(finishedDays)
    }
    
    static func previousFinishedSurveys(for studyBurstDay: Int) -> [RSDIdentifier : Int] {
        var surveyMap = [RSDIdentifier : Int]()
        let config = StudyBurstConfiguration()
        config.completionTasks.forEach {
            let day = $0.day
            guard studyBurstDay >= day else { return }
            $0.activityIdentifiers.forEach { (identifier) in
                surveyMap[identifier] = max(0, day - 1)
            }
        }
        return surveyMap
    }
    
    static let day1_startupState =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: [:],
                   finishedTodayTasks: [])
    
    static let day1_startupState_BRII_DTT =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: [:],
                   finishedTodayTasks: [],
                   timeUntilExpires: 0,
                   dataGroups: ["gr_SC_DB","gr_BR_II","gr_ST_T","gr_DT_T"])
    
    static let day1_startupState_BRII_DTF =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: [:],
                   finishedTodayTasks: [],
                   timeUntilExpires: 0,
                   dataGroups: ["gr_SC_DB","gr_BR_II","gr_ST_T","gr_DT_F"])
    
    static let day1_startupState_BRAD_DTT =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: [:],
                   finishedTodayTasks: [],
                   timeUntilExpires: 0,
                   dataGroups: ["gr_SC_DB","gr_BR_AD","gr_ST_T","gr_DT_T"])
    
    static let day1_startupState_BRAD_DTF =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: [:],
                   finishedTodayTasks: [],
                   timeUntilExpires: 0,
                   dataGroups: ["gr_SC_DB","gr_BR_AD","gr_ST_T","gr_DT_F"])
    
    static let day1_startupState_HeartSnapshot =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: [:],
                   finishedTodayTasks: [],
                   dataGroups: ["show_heartsnapshot"],
                   heartSnapshotCompletedDaysAgo: 100)
    
    static let day1_noTasksFinished =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [],
                   heartSnapshotCompletedDaysAgo: 100)
    
    static let day1_twoTasksFinished =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [.walkAndBalanceTask, .tappingTask],
                   heartSnapshotCompletedDaysAgo: 100)
    
    static let day1_tasksFinished_surveysNotFinished =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: RSDIdentifier.measuringTasks,
                   heartSnapshotCompletedDaysAgo: 0)
    
    static let day1_tasksFinished_surveysNotFinished_BRII_DTT =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [],
                   timeUntilExpires: 15,
                   dataGroups: ["gr_SC_DB","gr_BR_II","gr_ST_T","gr_DT_T"])
    
    static let day1_tasksFinished_surveysNotFinished_BRII_DTF =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [],
                   timeUntilExpires: 15,
                   dataGroups: ["gr_SC_DB","gr_BR_II","gr_ST_T","gr_DT_F"])
    
    static let day1_tasksFinished_surveysNotFinished_BRAD_DTT =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [],
                   timeUntilExpires: 15,
                   dataGroups: ["gr_SC_DB","gr_BR_AD","gr_ST_T","gr_DT_T"])
    
    static let day1_tasksFinished_surveysNotFinished_BRAD_DTF =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [],
                   timeUntilExpires: 15,
                   dataGroups: ["gr_SC_DB","gr_BR_AD","gr_ST_T","gr_DT_F"])
    
    static let day1_tasksFinished_surveysFinished =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 1),
                   finishedTodayTasks: RSDIdentifier.measuringTasks,
                   timeUntilExpires: 15,
                   dataGroups: ["gr_SC_DB","gr_BR_II","gr_ST_T","gr_DT_T","parkinsons"])
    
    static let day1_allFinished_2HoursAgo =
        StudySetup(0, studyBurstDay: 0,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 1),
                   finishedTodayTasks: RSDIdentifier.measuringTasks,
                   timeUntilExpires: -2 * 60 * 60)
    
    static let day2_twoFinished_2HoursAgo =
        StudySetup(0, studyBurstDay: 1,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 1),
                   finishedTodayTasks: [.walkAndBalanceTask, .tappingTask],
                   timeUntilExpires: -2 * 60 * 60,
                   heartSnapshotCompletedDaysAgo: 100)
    
    static let day2_nothingFinished =
        StudySetup(0, studyBurstDay: 1,
                   studyBurstFinishedOnDays: [],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [])
    
    static let day2_readyToStartTasks =
        StudySetup(0, studyBurstDay: 1,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 1),
                   finishedTodayTasks: [])
    
    static let day2_twoTasksFinished =
        StudySetup(0, studyBurstDay: 1,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 1),
                   finishedTodayTasks: [.tappingTask, .tremorTask])
    
    static let day2_surveysNotFinished =
        StudySetup(0, studyBurstDay: 1,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 0),
                   finishedTodayTasks: [])
    
    static let day2_tasksNotFinished_surveysFinished =
        StudySetup(0, studyBurstDay: 1,
                   studyBurstFinishedOnDays: [0],
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 1),
                   finishedTodayTasks: [])
    
    static let day9_twoTasksFinished =
        StudySetup(0, studyBurstDay: 8,
                   studyBurstFinishedOnDays: finishedOnDays(7, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 7),
                   finishedTodayTasks: [.walkAndBalanceTask, .tappingTask])
    
    static let day9_tasksFinished =
        StudySetup(0, studyBurstDay: 8,
                   studyBurstFinishedOnDays: finishedOnDays(7, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 7),
                   finishedTodayTasks: RSDIdentifier.measuringTasks)
    
    static let day11_tasksFinished_noMissingDays =
        StudySetup(0, studyBurstDay: 10,
                   studyBurstFinishedOnDays: finishedOnDays(10, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 10),
                   finishedTodayTasks: RSDIdentifier.measuringTasks)
    
    
    static let day14_missing1_tasksFinished_engagementNotFinished =
        StudySetup(0, studyBurstDay: 13,
                   studyBurstFinishedOnDays: finishedOnDays(13, 1),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: RSDIdentifier.measuringTasks)
    
    static let day14_missing6_tasksFinished_engagementNotFinished =
        StudySetup(0, studyBurstDay: 13,
                   studyBurstFinishedOnDays: finishedOnDays(13, 6),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: RSDIdentifier.measuringTasks)
    
    static let day14_tasksFinished_engagementNotFinished =
        StudySetup(0, studyBurstDay: 13,
                   studyBurstFinishedOnDays: finishedOnDays(13, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: RSDIdentifier.measuringTasks)
    
    static let day14_twoTasksFinished =
        StudySetup(0, studyBurstDay: 13,
                   studyBurstFinishedOnDays: finishedOnDays(13, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: [.walkAndBalanceTask, .tappingTask])
    
    static let day15_missing1_engagementNotFinished =
        StudySetup(0, studyBurstDay: 14,
                   studyBurstFinishedOnDays: finishedOnDays(14, 1),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: [])
    
    static let day15_missing10_engagementNotFinished =
        StudySetup(0, studyBurstDay: 14,
                   studyBurstFinishedOnDays: finishedOnDays(14, 10),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: [])
    
    static let day15_burstCompleted_engagementNotFinished =
        StudySetup(0, studyBurstDay: 14,
                   studyBurstFinishedOnDays: finishedOnDays(14, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: [])
    
    static let day15_burstCompleted_engagementFinished =
        StudySetup(0, studyBurstDay: 14,
                   studyBurstFinishedOnDays: finishedOnDays(14, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 14),
                   finishedTodayTasks: [])
    
    static let day21_missing6_engagementNotFinished =
        StudySetup(0, studyBurstDay: 20,
                   studyBurstFinishedOnDays: finishedOnDays(18, 6),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 12),
                   finishedTodayTasks: [])
    
    static let day21_tasksFinished_noMissingDays =
        StudySetup(0, studyBurstDay: 20,
                   studyBurstFinishedOnDays: finishedOnDays(14, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 14),
                   finishedTodayTasks: [])
    
    static let day89_tasksFinished_noMissingDays =
        StudySetup(0, studyBurstDay: 88,
                   studyBurstFinishedOnDays: finishedOnDays(14, 0),
                   studyBurstSurveyFinishedOnDays: previousFinishedSurveys(for: 14),
                   finishedTodayTasks: [])
}

public struct SurveyReference : Codable {
    
    let guid: String
    let identifier: RSDIdentifier
    let createdOn: String
    
    static var all: [SurveyReference] = {
        let surveyIdentifiers = ["Demographics", "Engagement", "Motivation", "Background", "Withdrawal"]
        let surveys: [SurveyReference] = surveyIdentifiers.compactMap {
            do {
                let transformer = RSDResourceTransformerObject(resourceName: $0)
                let data = try transformer.resourceData().data
                let decoder = RSDFactory.shared.createJSONDecoder()
                return try decoder.decode(SurveyReference.self, from: data)
            }
            catch let err {
                debugPrint("WARNING: Failed to decode \($0): \(err)")
                return nil
            }
        }
        return surveys
    }()
    
    var href: String {
        return "https://ws.sagebridge.org\(self.endpoint)"
    }
    
    var endpoint: String {
        return "/v3/surveys/\(self.guid)/revisions/\(self.createdOn)"
    }
    
    var label: String {
        switch identifier {
        case .demographics:
            return "Health Survey"
        case .engagement:
            return "Engagement Survey"
        default:
            return "Additional Survey Questions"
        }
    }
    
    var detail: String? {
        switch identifier {
        case .demographics:
            return "4 Minutes"
        case .engagement:
            return "6 Minutes"
        default:
            return nil
        }
    }
}

public class ActivityManager : NSObject, SBBActivityManagerProtocol {
    
    var schedules = [SBBScheduledActivity]()
    
    var finishedPersistentSchedules: [SBBScheduledActivity] = []
    
    var activityGuidMap : [RSDIdentifier : String] = [:]
    
    var studySetup: StudySetup = StudySetup()
    
    var participantManager: ParticipantManager!
    
    func buildSchedules(with participantManager: ParticipantManager) {
        self.participantManager = participantManager
        buildTrackingTasks(studySetup)
        buildMeasuringTasks(studySetup)
        buildStudyBurstTasks(studySetup)
    }
    
    func buildTrackingTasks(_ studySetup: StudySetup) {
        
        let activityGroup = SBAActivityGroupObject(identifier: RSDIdentifier.trackingTaskGroup.stringValue,
                                                   title: "Tracking",
                                                   journeyTitle: nil,
                                                   image: nil,
                                                   activityIdentifiers: [.triggersTask, .medicationTask, .symptomsTask],
                                                   notificationIdentifier: nil,
                                                   schedulePlanGuid: nil,
                                                   activityGuidMap: [
                                                    "Medication": "273c4518-7cb6-4496-b1dd-c0b5bf291b09",
                                                    "Symptoms": "60868b71-30a4-4e04-a00b-3aca6651deb2",
                                                    "Triggers": "b0f07b7e-408e-4d50-9368-8220971e570c"])
        
        activityGroup.activityIdentifiers.forEach { (identifier) in
            switch identifier {
            case .medicationTask:
                // TODO: syoung 05/23/2018 Add schedules for past days.
                // Medication task is set up for a single daily task.
                let scheduledOn = studySetup.now.startOfDay()
                let schedule = createSchedule(with: identifier,
                                          scheduledOn: scheduledOn,
                                          expiresOn: scheduledOn.addingNumberOfDays(1),
                                          finishedOn: nil,
                                          clientData: nil,
                                          schedulePlanGuid: activityGroup.schedulePlanGuid)
                self.schedules.append(schedule)
                
            default:
                // triggers and symptoms are persistent.
                let scheduledOn = studySetup.createdOn
                let schedule = createSchedule(with: identifier,
                                          scheduledOn: scheduledOn,
                                          expiresOn: nil,
                                          finishedOn: nil,
                                          clientData: nil,
                                          schedulePlanGuid: activityGroup.schedulePlanGuid)
                self.schedules.append(schedule)
            }
        }
    }
    
    func buildMeasuringTasks(_ studySetup: StudySetup) {
        
        let activityGroup = SBAActivityGroupObject(identifier: RSDIdentifier.measuringTaskGroup.stringValue,
                                                   title: "Measuring",
                                                   journeyTitle: nil,
                                                   image: nil,
                                                   activityIdentifiers: [.tappingTask, .tremorTask, .walkAndBalanceTask],
                                                   notificationIdentifier: nil,
                                                   schedulePlanGuid: "3d898a6f-1ef2-4ece-9e9f-025d94bcd130",
                                                   activityGuidMap: nil)
    
        // set default for the sort order
        let taskOrderTimestamp = studySetup.taskOrderTimestamp ?? studySetup.now
        let finishedTodayTasks = studySetup.finishedTodayTasks
        var sortOrder = finishedTodayTasks
        var unfinished = activityGroup.activityIdentifiers.filter { !finishedTodayTasks.contains($0) }
        unfinished.shuffle()
        sortOrder.append(contentsOf: unfinished)
        StudyBurstScheduleManager.setOrderedTasks(sortOrder.map { $0.stringValue }, timestamp: taskOrderTimestamp)
        
        let studyBurstFinishedOn = studySetup.mapStudyBurstFinishedOn()
        let studyBurstDates = studyBurstFinishedOn.enumerated().map { $0.element.value }.sorted()
        
        var schedules = [SBBScheduledActivity]()
        sortOrder.enumerated().forEach{ (offset, identifier) in
            
            let finishedTime: TimeInterval = studySetup.timeUntilExpires - 3600
            var datesToAdd = studyBurstDates
            if finishedTodayTasks.contains(identifier) {
                datesToAdd.append(taskOrderTimestamp.addingTimeInterval(finishedTime))
            }
            
            var scheduledOn = studySetup.createdOn
            datesToAdd.forEach {
                let finishedOn = $0.addingTimeInterval(TimeInterval(offset) * 4 * 60)
                let schedule = self.createSchedule(with: identifier,
                                                   scheduledOn: scheduledOn,
                                                   expiresOn: nil,
                                                   finishedOn: finishedOn,
                                                   clientData: nil,
                                                   schedulePlanGuid: activityGroup.schedulePlanGuid)
                schedules.append(schedule)
                scheduledOn = finishedOn
            }

            let schedule = createSchedule(with: identifier,
                                          scheduledOn: scheduledOn,
                                          expiresOn: nil,
                                          finishedOn: nil,
                                          clientData: nil,
                                          schedulePlanGuid: activityGroup.schedulePlanGuid)
            schedules.append(schedule)
        }
        
        let sortedSchedules = schedules.sorted(by: { $0.activityIdentifier!.compare($1.activityIdentifier!) == .orderedAscending })
        self.schedules.append(contentsOf: sortedSchedules)
    }
    
    func buildStudyBurstTasks(_ studySetup: StudySetup) {
        
        // only add the study burst marker for this group, but add one for each day.
        let createdOn = studySetup.createdOn
        let studyBurstFinishedOn = studySetup.mapStudyBurstFinishedOn()
        for day in 0..<19 {
            for burst in 0..<3 {
                let scheduledOn = createdOn.startOfDay().addingNumberOfDays(day + burst * 90)
                let finishedOn = (burst == 0) ? studyBurstFinishedOn[day] : nil
                let schedule = createSchedule(with: .studyBurstCompletedTask,
                                              scheduledOn: scheduledOn,
                                              expiresOn: scheduledOn.addingNumberOfDays(1),
                                              finishedOn: finishedOn,
                                              clientData: nil,
                                              schedulePlanGuid: nil)
                self.schedules.append(schedule)
            }
        }
        
        let surveyMap = studySetup.mapStudyBurstSurveyFinishedOn()
        
        // The completion tasks do not all have schedules but they still need reports added.
        let singletons = StudyBurstConfiguration().completionTaskIdentifiers
        singletons.forEach {
            guard surveyMap[$0] != nil else { return }
            participantManager.addReport(for: $0, studySetup)
        }
        
        // Add all the surveys that are suppose to be from the server.
        SurveyReference.all.forEach {
            let survey = createSchedule(with: $0.identifier,
                                              scheduledOn: studySetup.createdOn,
                                              expiresOn: nil,
                                              finishedOn: surveyMap[$0.identifier],
                                              clientData: nil,
                                              schedulePlanGuid: nil,
                                              survey: $0)
            self.schedules.append(survey)
        }
    }
    
    public func createSchedule(with identifier: RSDIdentifier, scheduledOn: Date, expiresOn: Date?, finishedOn: Date?, clientData: SBBJSONValue?, schedulePlanGuid: String?, survey: SurveyReference? = nil) -> SBBScheduledActivity {
        
        let guid = activityGuidMap[identifier] ?? UUID().uuidString
        activityGuidMap[identifier] = guid
        let scheduledOnString = (scheduledOn as NSDate).iso8601StringUTC()!
        let schedule = SBBScheduledActivity(dictionaryRepresentation: [
            "guid" : "\(guid):\(scheduledOnString)",
            "schedulePlanGuid" : schedulePlanGuid ?? UUID().uuidString
            ])!
        schedule.scheduledOn = scheduledOn
        schedule.expiresOn = expiresOn
        schedule.startedOn = finishedOn?.addingTimeInterval(-3 * 60)
        schedule.finishedOn = finishedOn
        schedule.clientData = clientData
        schedule.persistent = NSNumber(value: (expiresOn == nil) && (survey == nil))
        let activityType = (survey == nil) ? "task" : "survey"

        var dictionary = [
            "activityType" : activityType,
            "guid" : guid,
            "label" : survey?.label ?? activityLabel(for: identifier)
        ]
        dictionary["labelDetail"] = survey?.detail
        let activity = SBBActivity(dictionaryRepresentation: dictionary)!
        
        if let surveyRef = survey {
            activity.survey = SBBSurveyReference(dictionaryRepresentation: [
                "identifier" : identifier.stringValue,
                "guid" : surveyRef.guid,
                "createdOn" : surveyRef.createdOn,
                "href" : surveyRef.href
            ])
        }
        else {
            activity.task = SBBTaskReference(dictionaryRepresentation: [ "identifier" : identifier.stringValue ])
        }
        schedule.activity = activity
        
        if participantManager != nil {
            participantManager.addReport(for: schedule, with: studySetup)
        }
        
        return schedule
    }
    
    func activityLabel(for identifier: RSDIdentifier) -> String {
        switch identifier {
        case .studyBurstReminder:
            return "Set Study Burst Reminder"
        default:
            return identifier.stringValue
        }
    }
    
    func addFinishedPersistent(_ scheduledActivities: [SBBScheduledActivity]) {
        let filtered = scheduledActivities.filter { $0.persistentValue && $0.isCompleted }
        self.finishedPersistentSchedules.append(contentsOf: filtered)
    }
    
    public let offMainQueue = DispatchQueue(label: "org.sagebionetworks.BridgeApp.TestActivityManager")
    
    public func getScheduledActivities(from scheduledFrom: Date, to scheduledTo: Date, cachingPolicy policy: SBBCachingPolicy, withCompletion completion: @escaping SBBActivityManagerGetCompletionBlock) -> URLSessionTask {
        offMainQueue.async {
            
            // add a new schedule for the finished persistent schedules.
            let newSchedules = self.finishedPersistentSchedules.compactMap { (schedule) -> SBBScheduledActivity? in
                guard let finishedOn = schedule.finishedOn, let activityId = schedule.activityIdentifier else { return nil }
                return self.createSchedule(with: RSDIdentifier(rawValue: activityId),
                                    scheduledOn: finishedOn,
                                    expiresOn: nil,
                                    finishedOn: nil,
                                    clientData: nil,
                                    schedulePlanGuid: schedule.schedulePlanGuid)
            }
            self.schedules.append(contentsOf: newSchedules)
            self.finishedPersistentSchedules.removeAll()
            
            let predicate = SBBScheduledActivity.availablePredicate(from: scheduledFrom, to: scheduledTo)
            let filtered = self.schedules.filter { predicate.evaluate(with: $0) }
            completion(filtered, nil)
        }
        return URLSessionTask()
    }
    
    public func getScheduledActivities(from scheduledFrom: Date, to scheduledTo: Date, withCompletion completion: @escaping SBBActivityManagerGetCompletionBlock) -> URLSessionTask {
        return self.getScheduledActivities(from: scheduledFrom, to: scheduledTo, cachingPolicy: .fallBackToCached, withCompletion: completion)
    }
    
    public func getScheduledActivities(forDaysAhead daysAhead: Int, daysBehind: Int, cachingPolicy policy: SBBCachingPolicy, withCompletion completion: @escaping SBBActivityManagerGetCompletionBlock) -> URLSessionTask {
        fatalError("Deprecated")
    }
    
    public func getScheduledActivities(forDaysAhead daysAhead: Int, cachingPolicy policy: SBBCachingPolicy, withCompletion completion: @escaping SBBActivityManagerGetCompletionBlock) -> URLSessionTask {
        fatalError("Deprecated")
    }
    
    public func getScheduledActivities(forDaysAhead daysAhead: Int, withCompletion completion: @escaping SBBActivityManagerGetCompletionBlock) -> URLSessionTask {
        fatalError("Deprecated")
    }
    
    public func start(_ scheduledActivity: SBBScheduledActivity, asOf startDate: Date, withCompletion completion: SBBActivityManagerUpdateCompletionBlock? = nil) -> URLSessionTask {
        
        offMainQueue.async {
            if let schedule = self.schedules.first(where: { scheduledActivity.guid == $0.guid }) {
                schedule.startedOn = startDate
            } else {
                scheduledActivity.startedOn = startDate
                self.schedules.append(scheduledActivity)
            }
            completion?("passed", nil)
        }
        return URLSessionTask()
    }
    
    public func finish(_ scheduledActivity: SBBScheduledActivity, asOf finishDate: Date, withCompletion completion: SBBActivityManagerUpdateCompletionBlock? = nil) -> URLSessionTask {
        
        offMainQueue.async {
            if let schedule = self.schedules.first(where: { scheduledActivity.guid == $0.guid }) {
                schedule.finishedOn = finishDate
            } else {
                scheduledActivity.finishedOn = finishDate
                self.schedules.append(scheduledActivity)
            }
            self.addFinishedPersistent([scheduledActivity])
            completion?("passed", nil)
        }
        return URLSessionTask()
    }
    
    public func delete(_ scheduledActivity: SBBScheduledActivity, withCompletion completion: SBBActivityManagerUpdateCompletionBlock? = nil) -> URLSessionTask {
        offMainQueue.async {
            self.schedules.remove(where: { scheduledActivity.guid == $0.guid })
            completion?("passed", nil)
        }
        return URLSessionTask()
    }
    
    public func setClientData(_ clientData: SBBJSONValue, for scheduledActivity: SBBScheduledActivity, withCompletion completion: SBBActivityManagerUpdateCompletionBlock? = nil) -> URLSessionTask {
        offMainQueue.async {
            if let schedule = self.schedules.first(where: { scheduledActivity.guid == $0.guid }) {
                schedule.clientData = clientData
            } else {
                scheduledActivity.clientData = clientData
                self.schedules.append(scheduledActivity)
            }
            completion?("passed", nil)
        }
        return URLSessionTask()
    }
    
    public func updateScheduledActivities(_ scheduledActivities: [Any], withCompletion completion: SBBActivityManagerUpdateCompletionBlock? = nil) -> URLSessionTask {
        
        guard let scheduledActivities = scheduledActivities as? [SBBScheduledActivity]
            else {
                fatalError("Objects not of expected cast.")
        }
        
        offMainQueue.async {
            scheduledActivities.forEach { (scheduledActivity) in
                self.schedules.remove(where: { scheduledActivity.guid == $0.guid })
            }
            self.schedules.append(contentsOf: scheduledActivities)
            self.addFinishedPersistent(scheduledActivities)
            completion?("passed", nil)
        }
        return URLSessionTask()
    }
    
    public func getCachedSchedules(using predicate: NSPredicate, sortDescriptors: [NSSortDescriptor]?, fetchLimit: UInt) throws -> [SBBScheduledActivity] {
        
        var results = schedules.filter { predicate.evaluate(with: $0) }
        if let sortDescriptors = sortDescriptors {
            results = (results as NSArray).sortedArray(using: sortDescriptors) as! [SBBScheduledActivity]
        }
        
        return ((fetchLimit > 0) && (fetchLimit < results.count)) ? Array(results[..<Int(fetchLimit)]) : results
    }
}
