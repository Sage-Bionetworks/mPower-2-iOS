//
//  mPower2TestAppUITests.swift
//  mPower2TestAppUITests
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

class mPower2TestAppUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTrackingTab() {
        let app = XCUIApplication()
        let cellsQuery = app.collectionViews.cells
        
        let symptomImage = cellsQuery.otherElements.containing(.staticText, identifier:"SYMPTOM").images.count
        XCTAssertEqual(symptomImage, 1)
        
        let medicationImage = cellsQuery.otherElements.containing(.staticText, identifier:"MEDICATION").images.count
        XCTAssertEqual(medicationImage, 1)
        
        let triggerImage = cellsQuery.otherElements.containing(.staticText, identifier:"TRIGGER").images.count
        XCTAssertEqual(triggerImage, 1)
    }
    
    func testMeasuringTab() {
        
        // tap the "Measuring" tab
        let app = XCUIApplication()
        app.otherElements["Measuring"].children(matching: .button).element.tap()
        let cellsQuery = app.collectionViews.cells
        
        // Check that the icons are all there. Image count might be > 1 b/c of checkmark.
        let tappingImage = cellsQuery.otherElements.containing(.staticText, identifier:"FINGER TAPPING").images.count
        XCTAssertGreaterThanOrEqual(tappingImage, 1)
        
        let walkImage = cellsQuery.otherElements.containing(.staticText, identifier:"WALK AND BALANCE").images.count
        XCTAssertGreaterThanOrEqual(walkImage, 1)
        
        let tremorImage = cellsQuery.otherElements.containing(.staticText, identifier:"TREMOR TEST").images.count
        XCTAssertGreaterThanOrEqual(tremorImage, 1)
    }
    
}
