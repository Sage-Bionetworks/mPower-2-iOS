//
//  ParticipantManager.swift
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
@testable import BridgeSDK
@testable import BridgeApp

struct ReportData : Hashable {
    let identifer: String
    let timestamp: String
    let clientData: SBBJSONValue?
    
    var date: Date {
        return NSDate(iso8601String: timestamp) as Date
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifer)
        hasher.combine(timestamp)
    }
    
    static func == (lhs: ReportData, rhs: ReportData) -> Bool {
        return lhs.identifer == rhs.identifer && lhs.timestamp == rhs.timestamp
    }
    
    func reportData(for category: SBAReportCategory) -> SBBReportData {
        let reportData = SBBReportData(dictionaryRepresentation: [:])!
        reportData.data = self.clientData
        switch category {
        case .timestamp:
            reportData.dateTime = timestamp
        default:
            reportData.localDate = timestamp
        }
        return reportData
    }
}

public class ParticipantManager : NSObject, SBBParticipantManagerProtocol {

    var participant: SBBStudyParticipant!
    var reportDataObjects = Set<ReportData>()
    let reportManager = SBAReportManager()
    
    func setup(with studySetup: StudySetup) {
        self.participant = studySetup.createParticipant()
    }
    
    func addReport(for taskIdentifier: RSDIdentifier, _ studySetup: StudySetup) {
        let clientData = buildClientData(for: taskIdentifier, studySetup)
        let timestamp = (SBAReportSingletonDate as NSDate).iso8601DateOnlyString()!
        let report = ReportData(identifer: taskIdentifier.stringValue,
                                timestamp: timestamp,
                                clientData: clientData as NSDictionary)
        self.reportDataObjects.insert(report)
    }

    func addReport(for schedule: SBBScheduledActivity, with studySetup: StudySetup) {
        
        guard let finishedOn = schedule.finishedOn,
            let activityIdentifier = schedule.activityIdentifier
            else {
                return
        }
        let taskIdentifier = RSDIdentifier(rawValue: activityIdentifier)
        let schemaIdentifier = taskIdentifier == .studyBurstCompletedTask ? "StudyBurst" : activityIdentifier
        
        let category: SBAReportCategory = DataSourceManager.shared.categoryMapping[taskIdentifier] ?? .timestamp
        let clientData = buildClientData(for: taskIdentifier, studySetup)

        let timestamp: String = {
            switch category {
            case .singleton:
                return (SBAReportSingletonDate as NSDate).iso8601DateOnlyString()
            case .groupByDay:
                return (finishedOn as NSDate).iso8601DateOnlyString()
            case .timestamp:
                return (finishedOn as NSDate).iso8601String()
            }
        } ()

        let report = ReportData(identifer: schemaIdentifier,
                                timestamp: timestamp,
                                clientData: clientData as NSDictionary)
        self.reportDataObjects.insert(report)
    }
    
    func buildClientData(for taskIdentifier: RSDIdentifier, _ studySetup: StudySetup) -> [String : Any] {
        // TODO: syoung 05/23/2019 Support other reports.
        let clientData: [String : Any] = (taskIdentifier == .studyBurstReminder) ?
            [ "reminderTime" : studySetup.reminderTime ?? "09:00:00",
              "noReminder" : (studySetup.reminderTime == nil)
            ] : [:]
        return clientData
    }
    
    public let offMainQueue = DispatchQueue(label: "org.sagebionetworks.BridgeApp.TestParticipantManager")
    
    public func getParticipantRecord(completion: SBBParticipantManagerGetRecordCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func updateParticipantRecord(withRecord participant: Any?, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            if let newParticipant = participant as? SBBStudyParticipant {
                self.participant = newParticipant
                completion?(self.participant, nil)
            }
            else {
                let err = NSError(domain: "TestApp", code: 1, userInfo: nil)
                completion?(nil, err)
            }
        }
        return URLSessionTask()
    }
    
    public func setExternalIdentifier(_ externalID: String?, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            self.participant.externalId = externalID
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func setSharingScope(_ scope: SBBParticipantDataSharingScope, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            self.participant.sharingScope = scope.stringValue
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func getDataGroups(completion: @escaping SBBParticipantManagerGetGroupsCompletionBlock) -> URLSessionTask? {
        offMainQueue.async {
            completion(self.participant.dataGroups, nil)
        }
        return URLSessionTask()
    }
    
    public func updateDataGroups(withGroups dataGroups: Set<String>, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            self.participant.dataGroups = dataGroups
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func add(toDataGroups dataGroups: Set<String>, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            let previousGroups = self.participant.dataGroups ?? Set<String>()
            self.participant.dataGroups = previousGroups.union(dataGroups)
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func remove(fromDataGroups dataGroups: Set<String>, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {
            let previousGroups = self.participant.dataGroups ?? Set<String>()
            self.participant.dataGroups = previousGroups.subtracting(dataGroups)
            completion?(self.participant, nil)
        }
        return URLSessionTask()
    }
    
    public func getReport(_ identifier: String, fromTimestamp: Date, toTimestamp: Date, completion: @escaping SBBParticipantManagerGetReportCompletionBlock) -> URLSessionTask? {
        self._getReport(identifier, fromDate: fromTimestamp, toDate: toTimestamp, completion: completion)
        return URLSessionTask()
    }
    
    public func getReport(_ identifier: String, fromDate: DateComponents, toDate: DateComponents, completion: @escaping SBBParticipantManagerGetReportCompletionBlock) -> URLSessionTask? {
        let from = Calendar.iso8601.date(from: fromDate)
        let to = Calendar.iso8601.date(from: toDate)
        self._getReport(identifier, fromDate: from!, toDate: to!, completion: completion)
        return URLSessionTask()
    }
    
    func _getReport(_ identifier: String, fromDate: Date, toDate: Date, completion: @escaping SBBParticipantManagerGetReportCompletionBlock) {
        offMainQueue.async {
            let rsdIdentifier = RSDIdentifier(rawValue: identifier)
            let category = DataSourceManager.shared.categoryMapping[rsdIdentifier] ?? .timestamp
            let minDate = (category == .timestamp) ? fromDate : fromDate.startOfDay()
            let maxDate = (category == .timestamp) ? toDate : toDate.startOfDay().addingNumberOfDays(1)
            
            let reports = self.reportDataObjects.compactMap { (report) -> SBBReportData? in
                guard report.identifer == identifier else { return nil }
                let reportDate = report.date
                switch category {
                case .singleton:
                    return report.reportData(for: category)
                    
                case .groupByDay:
                    guard minDate <= reportDate && reportDate < maxDate else { return nil }
                    return report.reportData(for: category)
                    
                case .timestamp:
                    guard minDate <= reportDate && reportDate <= maxDate else { return nil }
                    return report.reportData(for: category)
                }
            }
            
            completion(reports, nil)
        }
    }
    
    public func save(_ reportData: SBBReportData, forReport identifier: String, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        offMainQueue.async {

            let rsdIdentifier = RSDIdentifier(rawValue: identifier)
            let category = DataSourceManager.shared.categoryMapping[rsdIdentifier] ?? .timestamp
            if let timestamp = (category == .timestamp) ? reportData.dateTime : reportData.localDate {
                let report = ReportData(identifer: identifier,
                                        timestamp: timestamp,
                                        clientData: reportData.data)
                // If there is an existing object with the same hash, then remove it and insert the new one.
                self.reportDataObjects.remove(report)
                self.reportDataObjects.insert(report)
            }
            else {
                assertionFailure("Failed to correctly set the timestamp to the correct date placeholder.")
            }
            
            completion?(nil, nil)
        }
        return URLSessionTask()
    }
    
    public func saveReportJSON(_ reportJSON: SBBJSONValue, withDateTime dateTime: Date, forReport identifier: String, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        
        let reportData = SBBReportData(dictionaryRepresentation: [:])!
        reportData.data = reportJSON
        reportData.dateTime = dateTime.jsonObject() as? String
        
        return self.save(reportData, forReport: identifier)
    }
    
    public func saveReportJSON(_ reportJSON: SBBJSONValue, withLocalDate dateComponents: DateComponents, forReport identifier: String, completion: SBBParticipantManagerCompletionBlock? = nil) -> URLSessionTask? {
        
        let reportData = SBBReportData(dictionaryRepresentation: [:])!
        reportData.data = reportJSON
        reportData.localDate = dateComponents.jsonObject() as? String
        
        return self.save(reportData, forReport: identifier)
    }
    
    public func getLatestCachedData(forReport identifier: String) throws -> SBBReportData {
        let reports = self.reportDataObjects.filter { $0.identifer == identifier }.sorted(by: { $0.date < $1.date })
        if let report = reports.last {
            let rsdIdentifier = RSDIdentifier(rawValue: identifier)
            let category = DataSourceManager.shared.categoryMapping[rsdIdentifier] ?? .timestamp
            return report.reportData(for: category)
        }
        else {
            return SBBReportData(dictionaryRepresentation: [:])!
        }
    }
}

extension SBBParticipantDataSharingScope {
    var stringValue: String {
        switch self {
        case .all:
            return "all"
        case .none:
            return "none"
        case .study:
            return "study"
        @unknown default:
            return "none"
        }
    }
}
