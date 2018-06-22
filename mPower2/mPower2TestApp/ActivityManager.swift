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
import Research

public struct StudySetup {
    init() { }
    
    /// First name of the participant.
    var firstName = "Rumplestiltskin"
    
    /// The data groups to set for this participant.
    var dataGroups: [String] = []
    
    /// The date when the participant started the study. Hardcoded to 6:15AM local time.
    var createdOn: Date {
        return Date().startOfDay().addingNumberOfDays(-1 * Int(studyBurstDay)).addingTimeInterval(6.25 * 60 * 60)
    }

    /// Study Burst "day" where Day 0 is the day the participant was "created".
    var studyBurstDay: UInt = 3
    
    /// The days in the past when the particpant finished all the tasks.
    var studyBurstFinishedOnDays: [Int] = [0, 2]
    
    var studyBurstSurveyFinishedOnDays: [RSDIdentifier : Int] = [:]
    
    /// Generated days of the study burst to mark as finished. This only applies to days that are past.
    func mapStudyBurstFinishedOn() -> [Int : Date] {
        let firstDay = createdOn.startOfDay().addingTimeInterval(8 * 60 * 60)
        return studyBurstFinishedOnDays.rsd_filteredDictionary { (day) -> (Int, Date)? in
            guard day < self.studyBurstDay else { return nil }
            let time = TimeInterval(arc4random_uniform(12 * 60 * 60))
            let timestamp = firstDay.addingNumberOfDays(day).addingTimeInterval(time)
            return (day, timestamp)
        }
    }
    
    /// Generated days of the study burst to mark as finished. This only applies to days that are past.
    func mapStudyBurstSurveyFinishedOn() -> [RSDIdentifier : Date] {
        let firstDay = createdOn.startOfDay().addingTimeInterval(8 * 60 * 60)
        return studyBurstSurveyFinishedOnDays.rsd_filteredDictionary { (input) -> (RSDIdentifier, Date)? in
            let day = input.value
            let time = TimeInterval(arc4random_uniform(12 * 60 * 60))
            let timestamp = firstDay.addingNumberOfDays(day).addingTimeInterval(time)
            return (input.key, timestamp)
        }
    }
    
    /// A list of the tasks to mark as finished today for a study burst. If included, this will be used to
    /// define the order of the tasks for display in the study burst view.
    var finishedTodayTasks: [RSDIdentifier] = [.tappingTask, .walkAndBalanceTask]
    
    /// The time to use as the time until today's finished tasks will expire. Default = 15 min.
    var timeUntilExpires: TimeInterval = 15 * 60
    
    func createParticipant() -> SBBStudyParticipant {
        return SBBStudyParticipant(dictionaryRepresentation: [
            "createdOn" : (createdOn as NSDate).iso8601String(),
            "dataGroups" : dataGroups,
            "firstName" : firstName,
            "phoneVerified" : NSNumber(value: true),
            ])!
    }
}

public class ActivityManager : NSObject, SBBActivityManagerProtocol {
    
    var schedules = [SBBScheduledActivity]()
    
    var finishedPersistentSchedules: [SBBScheduledActivity] = []
    
    var activityGuidMap : [RSDIdentifier : String] = [:]
    
    var studySetup: StudySetup = StudySetup()
    
    func buildSchedules() {
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
                let scheduledOn = Date().startOfDay()
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
    
        // measuring tasks are persistent.
        let finishedTodayTasks = studySetup.finishedTodayTasks
        var orderedTasks = finishedTodayTasks
        activityGroup.activityIdentifiers.forEach {
            if !orderedTasks.contains($0) {
                orderedTasks.append($0)
            }
        }
        
        UserDefaults.standard.set(orderedTasks.map { $0.stringValue }, forKey: "StudyBurstTaskOrder")
        UserDefaults.standard.set(Date(), forKey: "StudyBurstTimestamp")
        
        let studyBurstFinishedOn = studySetup.mapStudyBurstFinishedOn()
        let studyBurstDates = studyBurstFinishedOn.enumerated().map { $0.element.value }.sorted()
        orderedTasks.enumerated().forEach{ (offset, identifier) in
            
            let finishedTime: TimeInterval = studySetup.timeUntilExpires - 3600 + TimeInterval(offset) * 4 * 60
            var datesToAdd = studyBurstDates
            if finishedTodayTasks.contains(identifier) {
                datesToAdd.append(Date().addingTimeInterval(finishedTime))
            }
            
            var scheduledOn = studySetup.createdOn
            datesToAdd.forEach {
                let finishedOn = $0.addingTimeInterval(-1 * TimeInterval(offset) * 4 * 60)
                let schedule = self.createSchedule(with: identifier,
                                                   scheduledOn: scheduledOn,
                                                   expiresOn: nil,
                                                   finishedOn: finishedOn,
                                                   clientData: nil,
                                                   schedulePlanGuid: activityGroup.schedulePlanGuid)
                self.schedules.append(schedule)
                scheduledOn = finishedOn
            }

            let schedule = createSchedule(with: identifier,
                                          scheduledOn: scheduledOn,
                                          expiresOn: nil,
                                          finishedOn: nil,
                                          clientData: nil,
                                          schedulePlanGuid: activityGroup.schedulePlanGuid)
            self.schedules.append(schedule)
        }
    }
    
    func buildStudyBurstTasks(_ studySetup: StudySetup) {
        
        // only add the study burst marker for this group, but add one for each day.
        let createdOn = studySetup.createdOn
        let studyBurstFinishedOn = studySetup.mapStudyBurstFinishedOn()
        for day in 0..<19 {
            
            let scheduledOn = createdOn.startOfDay().addingNumberOfDays(day)
            let schedule = createSchedule(with: .studyBurstCompletedTask,
                                          scheduledOn: scheduledOn,
                                          expiresOn: scheduledOn.addingNumberOfDays(1),
                                          finishedOn: studyBurstFinishedOn[day],
                                          clientData: nil,
                                          schedulePlanGuid: nil)
            self.schedules.append(schedule)
        }
        
        let surveyMap = studySetup.mapStudyBurstSurveyFinishedOn()
        let demographics = createSchedule(with: .demographics,
                                          scheduledOn: studySetup.createdOn,
                                          expiresOn: nil,
                                          finishedOn: surveyMap[.demographics],
                                          clientData: nil,
                                          schedulePlanGuid: nil,
                                          activityType: "survey")
        demographics.persistent = NSNumber(value: false)
        self.schedules.append(demographics)
        
        let engagement = createSchedule(with: .engagement,
                                      scheduledOn: studySetup.createdOn,
                                      expiresOn: nil,
                                      finishedOn: surveyMap[.engagement],
                                      clientData: nil,
                                      schedulePlanGuid: nil,
                                      activityType: "survey")
        engagement.persistent = NSNumber(value: false)
        self.schedules.append(engagement)
        
        let studyBurstReminder = createSchedule(with: .studyBurstReminder,
                                        scheduledOn: studySetup.createdOn,
                                        expiresOn: nil,
                                        finishedOn: surveyMap[.studyBurstReminder],
                                        clientData: nil,
                                        schedulePlanGuid: nil)
        studyBurstReminder.persistent = NSNumber(value: false)
        self.schedules.append(studyBurstReminder)
    }
    
    public func createSchedule(with identifier: RSDIdentifier, scheduledOn: Date, expiresOn: Date?, finishedOn: Date?, clientData: SBBJSONValue?, schedulePlanGuid: String?, activityType: String? = nil) -> SBBScheduledActivity {
        
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
        schedule.persistent = NSNumber(value: (expiresOn == nil))
        let activityType = activityType ?? "task"

        let activity = SBBActivity(dictionaryRepresentation: [
            "activityType" : activityType,
            "guid" : guid,
            "label" : identifier.stringValue
            ])!
        if activityType == "survey" {
            activity.survey = SBBSurveyReference(dictionaryRepresentation: [
                "identifier" : identifier.stringValue,
                "guid" : UUID().uuidString,
                "href" : "http://example.org/\(identifier.stringValue)"
                ])
        }
        else {
            activity.task = SBBTaskReference(dictionaryRepresentation: [ "identifier" : identifier.stringValue ])
        }
        schedule.activity = activity
        
        return schedule
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
