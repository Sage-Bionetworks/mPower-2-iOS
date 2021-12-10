//
//  MTBDataArchive.swift
//  MobileToolboxWrapper
//
//
//  Copyright © 2016-2021 Sage Bionetworks. All rights reserved.
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
import JsonModel
import Research
import BridgeSDK

private let kDataGroups                       = "dataGroups"
private let kSchemaRevisionKey                = "schemaRevision"
private let kMetadataFilename                 = "metadata.json"

class MTBArchiveManager : NSObject, RSDDataArchiveManager {
    
    static let shared = MTBArchiveManager()
    
    /// A serial queue used to manage data crunching.
    let offMainQueue = DispatchQueue(label: "org.sagebionetworks.MobileToolboxWrapper.MTBArchiveManager")
    
    func archiveAndUpload(taskState: RSDTaskViewModel, schemaIdentifier: String, schemaRevision: Int?, dataGroups: Set<String>?) {
        let uuid = taskState.taskRunUUID ?? UUID()
        self._retainedPaths[uuid] = taskState
        self._schemaIdentifierMap[uuid] = schemaIdentifier
        self._schemaRevisionMap[uuid] = schemaRevision
        self._dataGroupsMap[uuid] = dataGroups
        offMainQueue.async {
            taskState.archiveResults(with: self) { (_ error: Error?) in
                self._retainedPaths[uuid] = nil
            }
        }
    }
    private var _retainedPaths: [UUID : RSDTaskViewModel] = [:]
    private var _schemaIdentifierMap: [UUID : String] = [:]
    private var _schemaRevisionMap: [UUID : Int] = [:]
    private var _dataGroupsMap: [UUID : Set<String>] = [:]
    
    func shouldContinueOnFail(for archive: RSDDataArchive, error: Error) -> Bool {
        debugPrint("ERROR! Failed to archive results: \(error)")
        // Flush the archive.
        (archive as? SBBDataArchive)?.remove()
        return false
    }
    
    func dataArchiver(for taskResult: RSDTaskResult, scheduleIdentifier: String?, currentArchive: RSDDataArchive?) -> RSDDataArchive? {
        guard currentArchive == nil,
                let topResult = taskResult as? AssessmentResult
        else {
            return currentArchive
        }
        
        // Look for a schema info associated with this portion of the task result. If not found, then
        // return the current archive.
        let uuid = topResult.taskRunUUID
        let schemaIdentifier = _schemaIdentifierMap[uuid]
        let archiveIdentifier = schemaIdentifier ?? taskResult.identifier
        let schemaRevision = _schemaRevisionMap[uuid]
        let dataGroups = _dataGroupsMap[uuid]
        
        return MTBDataArchive(identifier: archiveIdentifier,
                              schemaIdentifier: schemaIdentifier,
                              schemaRevision: schemaRevision ?? 1,
                              dataGroups: dataGroups)
    }
    
    /// Finalize the upload of all the created archives.
    public final func encryptAndUpload(taskResult: RSDTaskResult, dataArchives: [RSDDataArchive], completion:@escaping (() -> Void)) {
        let archives: [SBBDataArchive] = dataArchives.compactMap {
            guard let archive = $0 as? SBBDataArchive, self.shouldUpload(archive: archive) else { return nil }
            return archive
        }
        SBBDataArchive.encryptAndUploadArchives(archives)
        completion()
    }
    
    /// This method is called during `encryptAndUpload()` to allow subclasses to cancel uploading an archive.
    ///
    /// - returns: Whether or not to upload. Default is to return `true` if the archive is not empty.
    open func shouldUpload(archive: SBBDataArchive) -> Bool {
        return !archive.isEmpty()
    }
    
    /// By default, if an archive fails, the error is printed and that's all that is done.
    open func handleArchiveFailure(taskResult: RSDTaskResult, error: Error, completion:@escaping (() -> Void)) {
        debugPrint("WARNING! Failed to archive \(taskResult.identifier). \(error)")
        completion()
    }
}

class MTBDataArchive: SBBDataArchive, RSDDataArchive {

    /// The identifier for this archive.
    let identifier: String
    
    /// Store the task groups.
    let dataGroups: Set<String>?
    
    /// Does not support schedules.
    var scheduleIdentifier: String? { nil }
    
    init(identifier: String, schemaIdentifier: String?, schemaRevision: Int, dataGroups: Set<String>?) {
        self.identifier = identifier
        self.dataGroups = dataGroups
        super.init(reference: schemaIdentifier ?? identifier, jsonValidationMapping: nil)
        
        // set info values.
        self.setArchiveInfoObject(NSNumber(value: schemaRevision), forKey: kSchemaRevisionKey)
    }
    
    /// By default, the task result is not included and metadata are **not** archived directly, while the
    /// answer map is included.
    open func shouldInsertData(for filename: RSDReservedFilename) -> Bool {
        return true
    }
    
    /// Get the archivable object for the given result.
    open func archivableData(for result: ResultData, sectionIdentifier: String?, stepPath: String?) -> RSDArchivable? {
        result as? RSDArchivable
    }
    
    /// Insert the data into the archive. By default, this will call `insertData(intoArchive:,filename:, createdOn:)`.
    ///
    /// - note: The "answers.json" file is special-cased to *not* include the `.json` extension if this is
    /// for a `v1_legacy` archive. This allows the v1 schema to use `answers.foo` which reads better in the
    /// Synapse tables.
    open func insertDataIntoArchive(_ data: Data, manifest: RSDFileManifest) throws {
        let filename = manifest.filename
        let fileKey = (filename as NSString).deletingPathExtension
        if let reserved = RSDReservedFilename(rawValue: fileKey), reserved == .answers {
            self.dataFilename = filename
        }
        self.insertData(intoArchive: data, filename: filename, createdOn: manifest.timestamp)
        
        if filename == "taskData" {
            self.insertData(intoArchive: data, filename: "\(filename).json", createdOn: manifest.timestamp)
        }
    }
    
    /// Close the archive.
    open func completeArchive(with metadata: RSDTaskMetadata) throws {
        let metadataDictionary = try metadata.rsd_jsonEncodedDictionary()
        try completeArchive(createdOn: metadata.startDate, with: metadataDictionary)
    }
    
    /// Close the archive with optional metadata from a task result.
    open func completeArchive(createdOn: Date, with metadata: [String : Any]? = nil) throws {

        // Set up the activity metadata.
        var metadataDictionary: [String : Any] = metadata ?? [:]
        
        // Add the current data groups.
        if let dataGroups = self.dataGroups {
            metadataDictionary[kDataGroups] = dataGroups.joined(separator: ",")
        }
        
        // insert the dictionary.
        insertDictionary(intoArchive: metadataDictionary, filename: kMetadataFilename, createdOn: createdOn)
        
        // complete the archive.
        try complete()
    }
}

