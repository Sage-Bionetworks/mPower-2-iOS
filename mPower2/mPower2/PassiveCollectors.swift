//
//  PassiveCollectors.swift
//  mPower2
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

import Research
import BridgeApp
import CoreLocation
import CoreMotion
import BridgeSDK

private let kLastLocationKey: String = "MP2LastKnownLocation"
private let kLatitudeKey: String = "latitude"
private let kLongitudeKey: String = "longitude"
private let kPassiveDisplacementSchemaID: String = "PassiveDisplacement"
private let kPassiveDisplacementArchiveFilename: String = "displacement"
private let kPassiveGaitSchemaID: String = "PassiveGait"
private let kPassiveGaitRegionIdentifier: String = "passive-gait-geofence"

private let kSchemaRevisionKey: String = "schemaRevision"

private let kTimestampKey: String = "timestamp"
private let kDistanceKey: String = "distance"
private let kBearingKey: String = "bearing"
private let kSpeedKey: String = "speed"
private let kFloorKey: String = "floor"
private let kAltitudeKey: String = "altitude"
private let kHorizontalAccuracyKey: String = "horizontalAccuracy"
private let kVerticalAccuracyKey: String = "verticalAccuracy"

/// Protocol for location-services-triggered passive data collectors.
protocol PassiveLocationTriggeredCollector: class, CLLocationManagerDelegate {
    /// The schema identifier to which the collector should upload the data it collects.
    var schemaIdentifier: String { get }
    
    /// The CLLocationManager instance associated with this collector instance.
    var locationManager: CLLocationManager? { get set }
    
    /// Start the passive collector.
    func start()
    
    /// Stop the passive collector.
    func stop()
}

extension PassiveLocationTriggeredCollector {
    /// Check location authorization status, and request permission if not yet determined.
    func setupLocationManager() throws {
        // If it's already set up, just return
        guard self.locationManager == nil else { return }
        
        // Create a location manager instance and set ourselves as the delegate. We do this here so
        // even if authorization is currently not adequate for our needs, if that changes we'll get
        // a callback letting us know, and we can start monitoring then.
        self.locationManager = CLLocationManager()
        self.locationManager!.delegate = self
        self.locationManager!.allowsBackgroundLocationUpdates = true
        
        func authorizationError(for status: CLAuthorizationStatus) -> Error {
            let rsd_status: RSDAuthorizationStatus = (status == .restricted) ? .restricted : .denied
            let error = RSDPermissionError.notAuthorized(.location, rsd_status)
            #if DEBUG
            print("Not authorized to start the passive location recorder: \(rsd_status)")
            #endif
            return error
        }
        
        // Get the current status and exit early if the status is restricted or denied.
        let status = CLLocationManager.authorizationStatus()
        if status != .authorizedAlways && status != .notDetermined {
            // anything but "always" or "not yet asked" means we can't continue
            throw authorizationError(for: status)
        }
        
        guard status == .notDetermined else { return }
        
        // Authorization had not yet been given or denied, so we need to do that now and check again.
        self.locationManager!.requestAlwaysAuthorization()
        
        let newStatus = CLLocationManager.authorizationStatus()
        if newStatus != .authorizedAlways {
            // and here we are again
            throw authorizationError(for: newStatus)
        }
    }
}

// MARK: Passive Displacement Collection

/// This class allows us (with participant permission) to collect relative direction and distance
/// traveled information passively, in the background, as they go about their day.
@objc
class PassiveDisplacementCollector : NSObject, PassiveLocationTriggeredCollector {

    /// Returns the shared instance.
    static var shared: PassiveDisplacementCollector = PassiveDisplacementCollector(with: kPassiveDisplacementSchemaID)
    
    /// The schema identifier to which the collector should upload the data it collects.
    var schemaIdentifier: String
    
    /// The CLLocationManager instance associated with this collector instance.
    var locationManager: CLLocationManager? = nil
    
    /// Should we only collect relative distance and bearing (no actual latitude/longitude coordinates)? Defaults to true.
    var relativeDistanceOnly: Bool = true
    
    /// The last known location (stored in UserDefaults).
    var previousLocation: CLLocation? {
        get {
            guard let lastLocDict = UserDefaults.standard.dictionary(forKey: kLastLocationKey) else { return nil }
            let latitude = lastLocDict[kLatitudeKey] as! CLLocationDegrees
            let longitude = lastLocDict[kLongitudeKey] as! CLLocationDegrees
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        set {
            guard newValue != nil
                else {
                    UserDefaults.standard.removeObject(forKey: kLastLocationKey)
                    return
            }
            let lastLocDict = [
                kLatitudeKey: newValue!.coordinate.latitude,
                kLongitudeKey: newValue!.coordinate.longitude
            ]
            UserDefaults.standard.set(lastLocDict, forKey: kLastLocationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Create an instance with the specified schema identifier.
    init(with identifier: String) {
        schemaIdentifier = identifier
        super.init()
    }
    
    /// Start the passive displacement collector.
    func start() {
        // ...if we can.
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        
        DispatchQueue.main.async {
            if self.locationManager == nil {
                do {
                    try self.setupLocationManager()
                    self.locationManager!.pausesLocationUpdatesAutomatically = false
                } catch {
                    // we don't have permission to track their location passively so just ignore it
                    return
                }
            }

            self.locationManager!.startMonitoringSignificantLocationChanges()
        }
    }
    
    /// Stop the passive displacement collector.
    func stop() {
        DispatchQueue.main.async {
            self.locationManager?.stopMonitoringSignificantLocationChanges()
        }
    }
    
    /// Upload a PassiveDisplacementRecord
    func uploadDisplacement(_ displacementData: RSDDistanceRecord) {
        let archiveFilename = kPassiveDisplacementArchiveFilename
        let archive = SBBDataArchive(reference: schemaIdentifier, jsonValidationMapping: nil)
        if let schemaRevision = MP2BridgeConfiguration.shared.schemaInfo(for: schemaIdentifier)?.schemaVersion {
            archive.setArchiveInfoObject(schemaRevision, forKey: kSchemaRevisionKey)
        }
        
        do {
            let data = try displacementData.rsd_jsonEncodedData()
            archive.insertData(intoArchive: data, filename: archiveFilename, createdOn: Date())
            try archive.complete()
            archive.encryptAndUploadArchive()
        }
        catch {}
   }
    
    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            // hey we have permission now, yay! so (re)start monitoring
            start()
        } else {
            // we no longer have permission
            stop()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Generate & upload (a) displacement(s) from the given location(s)
        let validLocations = locations.filter({$0.horizontalAccuracy >= 0.0})
        for location in validLocations {
            if let lastLocation = previousLocation {
                let dataPoint = RSDDistanceRecord(uptime: ProcessInfo.processInfo.systemUptime,
                                                  timestamp: 0,
                                                  stepPath: "Passive",
                                                  location: location,
                                                  previousLocation: lastLocation,
                                                  totalDistance: nil,
                                                  relativeDistanceOnly: self.relativeDistanceOnly)
                uploadDisplacement(dataPoint)
            }
            previousLocation = location
        }
    }
}

// MARK: Passive Gait Collection

/// This class subclasses RSDTaskState so we can use the SBAArchiveManager to archive/upload it and clean up after.
/// It also implements RSDPathComponent so we can treat passive gait collection as an active task and reuse the
/// RSDMotionRecorder used by the Walk and Balance task.
class PassiveGaitModel: RSDTaskState, RSDPathComponent {
    var identifier: String = "walk"
    
    var currentChild: RSDNodePathComponent? = nil
    
    var parent: RSDPathComponent? = nil
        
    var isForwardEnabled: Bool = false
    
    var canNavigateBackward: Bool = false
    
    var outputDirectory: URL!
    
    open func pathResult() -> RSDResult {
        return self.taskResult
    }

    func perform(actionType: RSDUIActionType) {}
    
    init(schemaIdentifier: String) {
        var taskResult = RSDTaskResultObject(identifier: self.identifier, schemaInfo: MP2BridgeConfiguration.shared.schemaInfo(for: schemaIdentifier))
        taskResult.taskRunUUID = UUID()
        super.init(taskResult: taskResult)
        self.outputDirectory = self.createOutputDirectory()
    }
    
    // MARK: Task Finalization - The methods included in this section should **not** be called until the task is finished.
    
    override open func cleanup(error: Error?, completion: ((_ error: Error?) -> Void)? = nil) {
        self.deleteOutputDirectory(error: error, completion: completion)
    }
    
    /// Delete the output directory on the file management queue. Do *not* call this method until the
    /// files generated by this task have been copied to a new location, unless the results are being
    /// discarded.
    public func deleteOutputDirectory(error: Error?, completion:((_ error: Error?) -> Void)? = nil) {
        fileManagementQueue.async {
            
            guard let outputDirectory = self.outputDirectory else { return }
            var fileError: Error? = nil
            do {
                try FileManager.default.removeItem(at: outputDirectory)
            } catch let error {
                print("Error removing output directory: \(error.localizedDescription)")
                debugPrint("\tat: \(outputDirectory)")
                fileError = error
            }
            let reportedError = error ?? fileError
            completion?(reportedError)
        }
    }

}

/// This class allows us (with participant permission) to collect gait information passively,
/// in the background, as they go about their day.
@objc
class PassiveGaitCollector : NSObject, PassiveLocationTriggeredCollector {

    /// Returns the shared instance.
    static var shared: PassiveGaitCollector = PassiveGaitCollector(with: kPassiveGaitSchemaID)
    
    /// The schema identifier to which the collector should upload the data it collects.
    var schemaIdentifier: String
    
    /// The RSDMotionRecorder we use to record the motion data when needed.
    private var recorder: RSDMotionRecorder?
    
    /// The CMMotionActivityManager instance we use to listen for motion activity updates.
    private var activityManager: CMMotionActivityManager?
    
    /// The recorder configuration we use to set up the motion recorder.
    private var config: RSDMotionRecorderConfiguration
    
    /// The identifier with which to set up the recorder configuration.
    /// Since this is not part of an actual task, and the RSDTaskState object (viewModel) doesn't have
    /// a parent, this identifier appended with ".json" will be used as the name of the data samples
    /// file that gets uploaded in the archive.
    private var configIdentifier: String = "walk_motion"
    
    /// The types of motion data we want to collect.
    private var motionTypes: Set<RSDMotionRecorderType> = [.accelerometer, .gyro, .gravity, .userAcceleration, .attitude, .rotationRate]
    
    /// The CLLocationManager instance associated with this collector instance. We use geofences to
    /// wake up the app in the background when they start moving so we can get the activity type updates
    /// and, if they're walking, grab some walking data.
    internal var locationManager: CLLocationManager? = nil
    
    /// The last valid location reading we've gotten from Location Services (horizontalAccuracy >= 0).
    private var lastValidLocation: CLLocation?
    
    /// Are location updates currently paused?
    private var locationManagerPaused: Bool = true
    
    /// The view model we use for collecting and uploading the data.
    private var viewModel: PassiveGaitModel?
    
    /// The timer that stops motion data collection when it fires.
    private var timer: Timer?
    
    /// The notification listener for when other RSDMotionRecorder instances start.
    private var listener: NSObjectProtocol?
    
    /// The time at which the data collection started. Used to figure out if we got enough
    /// to be worth uploading.
    private var startTime: Date?

    /// The identifier for the background task that collects motion data.
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    /// The archive manager we use for archiving and uploading the results.
    private let archiveManager = SBAArchiveManager()
    
    /// Create an instance with the specified schema identifier.
    init(with identifier: String) {
        self.schemaIdentifier = identifier
        self.config = RSDMotionRecorderConfiguration(identifier: configIdentifier, recorderTypes: self.motionTypes)
    }
    
    #if DEBUG
    func debugNotification(title: String?, body: String?) {
        let localNote = UILocalNotification()
        let alertTitle = title ?? ""
        let alertBody = body ?? ""
        localNote.alertTitle = alertTitle
        localNote.alertBody = alertBody
        DispatchQueue.main.async {
            UIApplication.shared.presentLocalNotificationNow(localNote)
        }
        print("\(alertTitle) : \(alertBody)")
    }
    
    func describe(activity: CMMotionActivity?) -> String {
        guard let activity = activity else { return "<nil>" }
        return "start:\(activity.startDate) conf:\(activity.confidence.rawValue) still:\(activity.stationary) walk:\(activity.walking) run:\(activity.running) auto:\(activity.automotive) bike:\(activity.cycling) unk.:\(activity.unknown)"
    }
    #endif
    
    /// Start listening for activity updates, and if it says we've started walking, record an up-to-30-second burst
    /// of motion sensor data. Must be called on the main queue.
    /// - returns: a flag indicating whether activity updates were started.
    private func startActivityUpdates() -> Bool {
        guard let activityManager = self.activityManager else { return false }
        activityManager.startActivityUpdates(to: OperationQueue.main, withHandler: { (activity) in
            // If we get called without an activity object, ignore it.
            guard let activity = activity else { return }
            
            // Were we already recording a walk?
            let isAlreadyRecording = self.recorder != nil
            
            // Are we walking now?
            let isWalkingNow = (activity.walking == true) && (activity.confidence == .high)
            
            // We only care when the walking state changes:
            guard isAlreadyRecording != isWalkingNow else { return }
            
            // If we were recording a walk but we're not walking anymore, cut it short and go with what we've got.
            if isAlreadyRecording {
                #if DEBUG
                self.debugNotification(title: "Stopped walking", body: "\(self.describe(activity: activity))")
                #endif
                self.stopRecorderAndUpload()
            }
                // If we were *not* recording a walk already, but now we're walking, record and upload a 30-second burst
                // of motion sensor data.
            else {
                #if DEBUG
                self.debugNotification(title: "Logging", body: "\(self.describe(activity: activity))")
                #endif
                self.recordMotionSensorBurst()
            }
        })
        
        // Also, listen for active gait recorders being started, and when that happens shut ours down so we don't interfere.
        // This will be called on the posting queue, which for this notification is always main.
        self.listener = NotificationCenter.default.addObserver(forName: .RSDMotionRecorderWillStart, object: nil, queue: nil, using: { (notification) in
            guard let userInfo = notification.userInfo,
                let startedRecorder = userInfo[RSDIdentifier.motionRecorderInstance] as? RSDMotionRecorder,
                startedRecorder != self.recorder,
                self.recorder != nil,
                self.viewModel != nil
                else {
                    return
            }
            #if DEBUG
            self.debugNotification(title: "Active task needs motion recorder", body: "Stopping passive gait recorder")
            #endif
            self.stopRecorderAndUpload()
        })

        return true
    }
    
    /// Stop listening for motion activity updates. Must be called on the main queue.
    private func stopActivityUpdates() {
        guard let activityManager = self.activityManager else { return }
        activityManager.stopActivityUpdates()
        self.activityManager = nil
    }
    
    /// Start the passive gait collector.
    func start() {
        // No point in bothering if we can't tell whether or not they're walking.
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        self.activityManager = CMMotionActivityManager()
        
        // Request permissions when starting (i.e. at launch, or via other user interaction). For this we use a temporary
        // RSDMotionRecorder instance. Note that this recorder actually ignores the (non-optional) viewController argument
        // to the requestPermissions method.
        let viewController = AppDelegate.shared?.window?.rootViewController ?? UIViewController()
        let viewModel = PassiveGaitModel(schemaIdentifier: self.schemaIdentifier)
        let tempRecorder = self.config.instantiateController(with: viewModel) as? RSDMotionRecorder
        tempRecorder?.requestPermissions(on: viewController, { (action, result, error) in
            // If we got permission, start listening for activity updates to determine when to record gait data.
            self.startActivityUpdates()
        })
        
        // Start location services to set a geofence so we'll get woken up to check activity type when they go on the move.
        self.startLocationServices()
    }
    
    /// Try to start the location manager and set a geofence to get woken up when they start moving.
    /// If we can't, well, we can still try to collect gait data when the app gets woken for other reasons,
    /// like say background fetch. But that's going to be pretty hit-or-miss at best.
    func startLocationServices() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        
        DispatchQueue.main.async {
            if self.locationManager == nil {
                do {
                    try self.setupLocationManager()
                } catch {
                    // we don't have permission to track their location so just ignore it
                    return
                }
            }
            
            // This will get a good-enough initial fix and set a geofence.
            self.locationManagerPaused = true
            self.locationManager!.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager!.requestLocation()
        }

    }
    
    /// Stop the location manager.
    func stopLocationServices() {
        DispatchQueue.main.async {
            self.locationManager = nil
            self.locationManagerPaused = true
        }
    }
    
    /// Stop the passive gait collector altogether.
    func stop() {
        DispatchQueue.main.async {
            self.stopActivityUpdates()
        }
        stopLocationServices()
        guard let listener = self.listener else { return }
        self.listener = nil
        NotificationCenter.default.removeObserver(listener)
    }
    
    /// Collect and upload up to 30 seconds of motion data in the background.
    /// Assumes you checked that self.recorder was nil before calling this method.
    func recordMotionSensorBurst() {
        guard RSDMotionRecorder.current == nil
            else {
                #if DEBUG
                debugNotification(title: "Not recording", body: "Another motion recorder instance is already running")
                #endif
                return
        }
        #if DEBUG
        debugNotification(title: "Recording", body: "30 seconds of motion sensors starting at \(Date())")
        #endif
        self.viewModel = PassiveGaitModel(schemaIdentifier: self.schemaIdentifier)
        self.recorder = self.config.instantiateController(with: self.viewModel!) as? RSDMotionRecorder
        self.recorder?.start() { (action, result, error) in
            guard error == nil else {
                #if DEBUG
                self.debugNotification(title: "Failed to start motion recorder", body: "\(error!)")
                #endif
                self.recorder = nil
                self.viewModel = nil
                return
            }
            
            // if we've already (still) got a background task going, just bail
            guard self.backgroundTaskId == .invalid else { return }
            
            // mark the time
            self.startTime = Date()
            
            // try to get up to 30 seconds of motion data, but take whatever iOS gives us
            self.timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) {_ in
                self.stopRecorderAndUpload()
            }

            self.backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "Passive gait collection") {
                // if we get a callback that we're out of time before our timer expires, upload whatever we managed to get
                #if DEBUG
                let elapsedTime = Date().timeIntervalSince(self.startTime!)
                self.debugNotification(title: "Cutting it short", body: "background task about to expire after \(elapsedTime) seconds")
                #endif
                self.stopRecorderAndUpload()
            }
        }
    }
    
    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
        self.backgroundTaskId = .invalid
    }
    
    #if DEBUG
    func archiveErrorDesc(_ error: Error?) -> String {
        guard let error = error else { return "No errors reported" }
        guard let nserror = error as NSError?,
                let underlyingError = nserror.userInfo[NSUnderlyingErrorKey] as? NSError
            else {
                return error.localizedDescription
        }
        let shortDomain = nserror.domain.components(separatedBy: ".").last ?? "???"
        let ulShortDomain = underlyingError.domain.components(separatedBy: ".").last ?? "???"
        return "Err cd \(nserror.code) - \(shortDomain): UL Err Cd \(underlyingError.code) - \(ulShortDomain) \(underlyingError.localizedDescription)"
    }
    #endif
    
    func stopRecorderAndUpload() {
        guard let taskState = self.viewModel,
                let recorder = self.recorder,
                let timer = self.timer,
                let startTime = self.startTime
            else {
                return
        }
        self.timer = nil
        self.viewModel = nil
        self.startTime = nil
        self.recorder = nil

        // kill the timer if it's still running
        if timer.isValid {
            timer.invalidate()
        }
        
        #if DEBUG
        debugNotification(title: "Stopping motion sensors", body: "as of \(Date())")
        #endif
        
        recorder.stop() { (action, result, error) in
            let duration = Date().timeIntervalSince(startTime)
            
            if error == nil, let result = result, duration >= 15.0 {
                #if DEBUG
                self.debugNotification(title: "Archiving", body: "\(taskState)")
                #endif
                
                taskState.taskResult.appendAsyncResult(with: result)
                
                self.archiveManager.archiveAndUpload(taskState) { (_ error: Error?) in
                    #if DEBUG
                    self.debugNotification(title: "Done archiving", body: self.archiveErrorDesc(error))
                    #endif
                }
                self.endBackgroundTask()
            }
            else {
                #if DEBUG
                if error != nil {
                    self.debugNotification(title: "Error stopping recorder", body: "\(error!)")
                }
                else if result == nil {
                    self.debugNotification(title: "Stopping recorder", body: "No error reported, but result is nil")
                }
                else {
                    self.debugNotification(title: "Not enough data", body: "only got \(duration) seconds")
                }
                #endif
                taskState.deleteOutputDirectory(error: error)
                self.endBackgroundTask()
            }
        }
    }
    
    // MARK: CLLocationManagerDelegate
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // This gets called when we are at some place and Location Services thinks we're going to be here
        // for a while. So, let's set a geofence around it so we'll get pinged when we leave.
        guard manager == self.locationManager else { return }
        #if DEBUG
        debugNotification(title: "Pausing location updates", body: nil)
        #endif
        self.locationManagerPaused = true
        
        // In order to do that though, we need to get a good fix on our location first, and handle it
        // in the didUpdateLocations delegate method.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestLocation()
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        guard manager == self.locationManager else { return }
        #if DEBUG
        debugNotification(title: "Resuming location updates", body: nil)
        #endif
        self.locationManagerPaused = false
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard manager == self.locationManager,
                region.identifier == kPassiveGaitRegionIdentifier
            else {
                return
        }
        #if DEBUG
        debugNotification(title: "Left the region", body: "Starting location updates")
        #endif

        manager.stopMonitoring(for: region)
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard manager == self.locationManager else { return }
        #if DEBUG
        debugNotification(title: "Error monitoring region", body: "\(error)")
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            // hey we have permission now, yay! so (re)start monitoring
            startLocationServices()
        } else {
            // we no longer have permission
            stopLocationServices()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard manager == self.locationManager else { return }

        // Listen for most recent valid location reading
        guard let validLocation = locations.filter( { $0.horizontalAccuracy >= 0 } ).last else { return }
        self.lastValidLocation = validLocation
        
        // If the location manager is paused, and we're getting readings, that means we got the pause callback and
        // requested an accurate location, so when we get one that's accurate enough, use it to set a geofence
        if self.locationManagerPaused {
            if validLocation.horizontalAccuracy < 100.0 {
                #if DEBUG
                debugNotification(title: "Setting geofence", body: "\(validLocation)")
                #endif
                // use an accuracy no more precise than what we get from wifi so we don't keep the GPS radio turned on
                let accuracy = max(validLocation.horizontalAccuracy, 65.0)
                let geofence = CLCircularRegion(center: validLocation.coordinate, radius: accuracy, identifier: kPassiveGaitRegionIdentifier)
                manager.startMonitoring(for: geofence)
                manager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard manager == self.locationManager else { return }
        // log it
        #if DEBUG
        debugNotification(title: "Location manager failed", body: "\(error)")
        #endif
    }
}