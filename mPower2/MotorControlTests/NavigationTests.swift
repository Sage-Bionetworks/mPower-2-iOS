//
//  NavigationTests.swift
//  MotorControlTests
//
//  Created by Robert Kolmos on 4/6/18.
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//

@testable import MotorControl
import XCTest

class NavigationTests: XCTestCase {
    
    var taskController : TestTaskController!
    var steps : [RSDStep]!
    
    
    override func setUp() {
        self.steps = []
        let firstSteps : [RSDStep] = TestStep.steps(from: ["overview", "instruction"])
        self.steps.append(contentsOf: firstSteps)
        let leftSectionSteps : [RSDStep] = TestStep.steps(from: ["leftInstruction", "leftActive"])
        let leftSectionObject : RSDSectionStepObject = RSDSectionStepObject(identifier: "left", steps: leftSectionSteps)
        let leftSection = MCTSkipableSectionStepObject(with: leftSectionObject)
        self.steps.append(leftSection)
        let rightSectionSteps : [RSDStep] = TestStep.steps(from: ["rightInstruction", "rightActive"])
        let rightSectionObject : RSDSectionStepObject = RSDSectionStepObject(identifier: "right", steps: rightSectionSteps)
        let rightSection = MCTSkipableSectionStepObject(with: rightSectionObject)
        self.steps.append(rightSection)
        let finalSteps : [RSDStep] = TestStep.steps(from: ["completion"])
        self.steps.append(contentsOf: finalSteps)
        self.taskController = TestTaskController()
        
        var navigator = TestConditionalNavigator(steps: steps)
        navigator.progressMarkers = ["overview", "instruction", "left", "right", "completion"]
        
        let task = TestTask(identifier: "test", stepNavigator: navigator)
        
        self.taskController = TestTaskController()
        self.taskController.topLevelTask = task
        super.setUp()
    }
    
    override func tearDown() {
        self.taskController = nil
        self.steps = nil
        super.tearDown()
    }
    
    private func _insertHandSelectionResult(for taskController: TestTaskController) {
        var collectionResult = RSDCollectionResultObject(identifier: "handSelection")
        var answerResult = RSDAnswerResultObject(identifier: "handSelection", answerType: .string)
        if self.taskController.handSelection!.count == 2 {
            answerResult.value = "both"
        } else {
            answerResult.value = self.taskController.handSelection!.first!
        }
        
        collectionResult.appendInputResults(with: answerResult)
        let answerType = RSDAnswerResultType(baseType: .string, sequenceType: .array)
        var handOrderResult = RSDAnswerResultObject(identifier: MCTHandSelectionDataSource.handOrderKey, answerType: answerType)
        handOrderResult.value = self.taskController.handSelection
        collectionResult.appendInputResults(with: handOrderResult)
        self.taskController.taskPath.appendStepHistory(with: collectionResult)
    }
    
    private func _insertIsFirstRunResult(for taskController: TestTaskController, isFirstRun: Bool) {
        var answerResult = RSDAnswerResultObject(identifier: "isFirstRun", answerType: .boolean)
        answerResult.value = isFirstRun
        self.taskController.taskPath.appendStepHistory(with: answerResult)
    }
    
    private func _setupInstructionStepTest() {
        self.steps = []
        let firstSteps : [RSDStep] = TestStep.steps(from: ["first"])
        self.steps.append(contentsOf: firstSteps)
        self.steps.append(MCTInstructionStepObject(identifier: "instructionFirstRunOnly", type: .instruction, isFirstRunOnly: true))
        self.steps.append(MCTInstructionStepObject(identifier: "instructionNotFirstRunOnly", type: .instruction, isFirstRunOnly: false))
        let finalSteps : [RSDStep] = TestStep.steps(from: ["completion"])
        self.steps.append(contentsOf: finalSteps)
        self.taskController = TestTaskController()
        
        var navigator = TestConditionalNavigator(steps: steps)
        navigator.progressMarkers = ["overview", "instructionFirstRunOnly", "instructionNotFirstRunOnly", "completion"]
        
        let task = TestTask(identifier: "test", stepNavigator: navigator)
        
        self.taskController = TestTaskController()
        self.taskController.topLevelTask = task
        super.setUp()
    }
    
    public func testSkippableSection_Left() {
        self.taskController.handSelection = ["left"]
        _insertHandSelectionResult(for: self.taskController)
        let _ = self.taskController.test_stepTo("instruction")
        // Go forward to the leftInstruction step
        self.taskController.goForward()
        var stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "leftInstruction")
        // Go forward into the leftActive step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "leftActive")
        // Go forward to the completion step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "completion")
    }
    
    public func testSkippableSection_Right() {
        self.taskController.handSelection = ["right"]
        _insertHandSelectionResult(for: self.taskController)
        let _ = self.taskController.test_stepTo("instruction")
        // Go forward to the rightInstruction step
        self.taskController.goForward()
        var stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "rightInstruction")
        // Go forward into the rightActive step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "rightActive")
        // Go forward to the completion step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "completion")
    }

    public func testSkippableSection_LeftThenRight() {
        self.taskController.handSelection = ["left", "right"]
        _insertHandSelectionResult(for: self.taskController)
        let _ = self.taskController.test_stepTo("instruction")
        // Go forward to the leftInstruction step
        self.taskController.goForward()
        var stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "leftInstruction")
        // Go forward into the leftActive step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "leftActive")
        // Go forward to the rightInstruction step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "rightInstruction")
        // Go forward into the rightActive step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "rightActive")
        // Go forward to the completion step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "completion")
    }
    
    public func testSkippableSection_RightThenLeft() {
        self.taskController.handSelection = ["right", "left"]
        _insertHandSelectionResult(for: self.taskController)
        let _ = self.taskController.test_stepTo("instruction")
        // Go forward to the rightInstruction step
        self.taskController.goForward()
        var stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "rightInstruction")
        // Go forward into the rightActive step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "rightActive")
        // Go forward to the leftInstruction step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "leftInstruction")
        // Go forward into the leftActive step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "leftActive")
        // Go forward to the completion step
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "completion")
    }
    
    public func testInstructionStep_firstRun() {
        _setupInstructionStepTest()
        _insertIsFirstRunResult(for: self.taskController, isFirstRun: true)
        let _ = self.taskController.test_stepTo("first")
        // Go forward, shouldn't skip the instructionFirstRunOnly
        self.taskController.goForward()
        var stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "instructionFirstRunOnly")
        // Go forward, shouldn't skip the instructionNotFirstRunOnly step either
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "instructionNotFirstRunOnly")
        // Go forward should proceed from instructionNotFirstRunOnly to completion
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "completion")
    }
    
    public func testInstructionStep_notFirstRun() {
        _setupInstructionStepTest()
        _insertIsFirstRunResult(for: self.taskController, isFirstRun: false)
        let _ = self.taskController.test_stepTo("first")
        // Go forward, should skip the instructionFirstRunOnly
        self.taskController.goForward()
        var stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "instructionNotFirstRunOnly")
        // Go forward should proceed from instructionNotFirstRunOnly to completion
        self.taskController.goForward()
        stepTo = self.taskController.navigate_calledTo
        XCTAssertNotNil(stepTo)
        XCTAssertEqual(stepTo!.identifier, "completion")
    }
}
