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
import CoreLocation
import BridgeSDK

private let kLastLocationKey: String = "MP2LastKnownLocation"
private let kLatitudeKey: String = "latitude"
private let kLongitudeKey: String = "longitude"
private let kPassiveDisplacementSchemaID: String = "PassiveDisplacement"
private let kPassiveDisplacementArchiveFilename: String = "displacement"
private let kSchemaRevisionKey: String = "schemaRevision"

private let kTimestampKey: String = "timestamp"
private let kDistanceKey: String = "distance"
private let kBearingKey: String = "bearing"
private let kSpeedKey: String = "speed"
private let kFloorKey: String = "floor"
private let kAltitudeKey: String = "altitude"
private let kHorizontalAccuracyKey: String = "horizontalAccuracy"
private let kVerticalAccuracyKey: String = "verticalAccuracy"

/// Protocol for passive data collectors.
protocol PassiveCollector {
    /// The schema identifier to which the collector should upload the data it collects.
    var schemaIdentifier: String { get }
    
    /// Start the passive collector.
    func start()
    
    /// Stop the passive collector.
    /// - parameter discarding: true if pending data since the last upload should be discarded, false if it should be uploaded.
    func stop(discarding: Bool)
}

/// This class allows us (with participant permission) to collect relative direction and distance
/// traveled information passively, in the background, as they go about their day.
@objc
class PassiveDisplacementCollector : NSObject, PassiveCollector, CLLocationManagerDelegate {

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
    
    /// Check location authorization status, and request permission if not yet determined.
    private func setupLocationManager() throws {
        // If it's already set up, just return
        guard self.locationManager == nil else { return }
        
        // Create a location manager instance and set ourselves as the delegate. We do this here so
        // even if authorization is currently not adequate for our needs, if that changes we'll get
        // a callback letting us know, and we can start monitoring then.
        self.locationManager = CLLocationManager()
        self.locationManager!.delegate = self
        self.locationManager!.allowsBackgroundLocationUpdates = true
        self.locationManager!.pausesLocationUpdatesAutomatically = false
        
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

    /// Start the passive displacement collector.
    func start() {
        // ...if we can.
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        
        DispatchQueue.main.async {
            if self.locationManager == nil {
                do {
                    try self.setupLocationManager()
                } catch {
                    // we don't have permission to track their location passively so just ignore it
                    return
                }
            }

            self.locationManager!.startMonitoringSignificantLocationChanges()
        }
    }
    
    /// Stop the passive displacement collector.
    /// - parameter discarding: Ignored by this collector; it gets data infrequently enough to just upload as it goes.
    func stop(discarding: Bool) {
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
            // we no longer have permission, but we can still upload what we collected while we did
            stop(discarding: false)
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

/// This class allows us (with participant permission) to collect gait information passively,
/// in the background, as they go about their day.
class PassiveGaitCollector : PassiveCollector {
    /// The schema identifier to which the collector should upload the data it collects.
    var schemaIdentifier: String

    /// Create an instance with the specified schema identifier.
    init(with identifier: String) {
        schemaIdentifier = identifier
    }
    
    /// Start the passive gait collector.
    func start() {
        
    }
    
    /// Stop the passive gait collector.
    /// - parameter discarding: true if pending gait data since the last upload should be discarded, false if it should be uploaded.
    func stop(discarding: Bool) {
        
    }
}
