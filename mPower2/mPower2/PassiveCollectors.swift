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
    
    /// The last known location (stored in UserDefaults)
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
        guard locationManager == nil else { return }
        
        // Create a location manager instance and set ourselves as the delegate. We do this here so
        // even if authorization is currently not adequate for our needs, if that changes we'll get
        // a callback letting us know, and we can start monitoring then.
        locationManager = CLLocationManager()
        locationManager!.delegate = self
        locationManager!.allowsBackgroundLocationUpdates = true
        locationManager!.pausesLocationUpdatesAutomatically = false
        
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
        locationManager!.requestAlwaysAuthorization()
        
        let newStatus = CLLocationManager.authorizationStatus()
        if newStatus != .authorizedAlways {
            // and here we are again
            throw authorizationError(for: newStatus)
        }
    }

    /// Start the passive mobility collector.
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
    
    /// Stop the passive mobility collector.
    /// - parameter discarding: true if pending mobility data since the last upload should be discarded, false if it should be uploaded.
    func stop(discarding: Bool) {
        // if there's no locationManager, there's nothing to do
        guard locationManager != nil else { return }
        
        if !discarding {
            // TODO: emm 2018-10-02 check if there's data and upload it
        }
        
        self.locationManager!.stopMonitoringSignificantLocationChanges()
    }
    
    /// Given a current and previous location reading, generate a displacement data point.
    func displacementData(for location: CLLocation, previousLocation: CLLocation) -> [String: RSDJSONValue] {
        let timestamp = (location.timestamp as NSDate).iso8601String()!
        let distance = location.distance(from: previousLocation)
        let bearing = previousLocation.bearingInRadians(to: location)
        let speed = (location.speed >= 0) ? location.speed : nil
        let floor = location.floor?.level
        let altitude = (location.verticalAccuracy >= 0) ? location.altitude : nil
        let horizontalAccuracy = location.horizontalAccuracy
        let verticalAccuracy = (location.verticalAccuracy >= 0) ? location.verticalAccuracy : nil
        
        // initialize dataPoint dict with the non-optional values
        var dataPoint: [String: RSDJSONValue] = [
            kTimestampKey: timestamp,
            kDistanceKey: distance,
            kBearingKey: bearing,
            kHorizontalAccuracyKey: horizontalAccuracy
        ]
        
        // now set the optional ones that are not nil
        dataPoint[kSpeedKey] = speed
        dataPoint[kFloorKey] = floor
        dataPoint[kAltitudeKey] = altitude
        dataPoint[kVerticalAccuracyKey] = verticalAccuracy
        
        return dataPoint
    }
    
    func uploadDisplacement(_ displacementData: [String: RSDJSONValue]) {
        let archiveFilename = kPassiveDisplacementArchiveFilename
        let archive = SBBDataArchive(reference: schemaIdentifier, jsonValidationMapping: nil)
        if let schemaRevision = MP2BridgeConfiguration.shared.schemaInfo(for: schemaIdentifier)?.schemaVersion {
            archive.setArchiveInfoObject(schemaRevision, forKey: kSchemaRevisionKey)
        }
        archive.insertDictionary(intoArchive: displacementData, filename: archiveFilename, createdOn: Date())
        
        do {
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
                let dataPoint = displacementData(for: location, previousLocation: lastLocation)
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


extension CLLocation {
    static func toRadians(from degrees: CLLocationDegrees) -> Double {
        return (degrees / 180.0) * .pi
    }
    
    static func toDegrees(from radians: Double) -> CLLocationDegrees {
        return (radians / .pi) * 180.0
    }
    
    func bearingInRadians(to endLocation: CLLocation) -> Double {
        // https://www.igismap.com/formula-to-find-bearing-or-heading-angle-between-two-points-latitude-longitude/
        let theta_a = CLLocation.toRadians(from: self.coordinate.latitude)
        let La = CLLocation.toRadians(from: self.coordinate.longitude)
        let theta_b = CLLocation.toRadians(from: endLocation.coordinate.latitude)
        let Lb = CLLocation.toRadians(from: endLocation.coordinate.longitude)
        let delta_L = Lb - La
        let X = cos(theta_b) * sin(delta_L)
        let Y = cos(theta_a) * sin(theta_b) - sin(theta_a) * cos(theta_b) * cos(delta_L)
        
        return atan2(X, Y)
    }
}
