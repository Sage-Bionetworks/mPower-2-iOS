//
//  ResourceTests.swift
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
@testable import BridgeApp
import ResearchV2
import BridgeApp

class ResourceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {

        XCTAssertTrue(true)
    }
    
    func testSigninTask() {
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: "SignIn")
            let task = try RSDFactory.shared.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the SignIn task. \(err)")
        }
    }
    
    func testAppConfig() {
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: "AppConfig")
            let (data, resourceType) = try resourceTransformer.resourceData()
            XCTAssertEqual(resourceType, .json)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let clientData = (json as? [String : Any])?["clientData"] as? SBBJSONValue else {
                XCTFail("Failed to decode clientData. \(json)")
                return
            }
            let decoder = MP2Factory().createJSONDecoder()
            let mappingObject = try decoder.decode(SBAActivityMappingObject.self, from: clientData)
            
            XCTAssertEqual(mappingObject.studyDuration?.year, 2)
            
        } catch let err {
            XCTFail("Failed to decode the SignIn task. \(err)")
        }
    }
    
    func testSignIn() {
        let identifier = "SignIn"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
    
    func testActivityTracking() {
        let identifier = "ActivityTracking"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
    
    func testPassiveDataPermission() {
        let identifier = "PassiveDataPermission"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
    
    func testTriggers() {
        let identifier = "Triggers"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
    
    func testSymptoms() {
        let identifier = "Symptoms"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
    
    func testMedication() {
        let identifier = "Medication"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
    
    func testStudyBurstReminder() {
        let identifier = "StudyBurstReminder"
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: identifier)
            let factory = MP2Factory()
            let task = try factory.decodeTask(with: resourceTransformer)
            try task.validate()
        } catch let err {
            XCTFail("Failed to decode the \(identifier) task. \(err)")
        }
    }
}
