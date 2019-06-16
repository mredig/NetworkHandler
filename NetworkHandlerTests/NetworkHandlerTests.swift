//
//  NetworkHandlerTests.swift
//  NetworkHandlerTests
//
//  Created by Michael Redig on 5/29/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import XCTest
@testable import NetworkHandler

class NetworkHandlerTests: XCTestCase {

	var demoModelController: DemoModelController?
	let imageURL = URL(string: "https://placekitten.com/300/300")!

	override func setUp() {
		demoModelController = DemoModelController()
	}

	func testCRUD() {
		guard let demoModelController = demoModelController else {
			XCTFail("No Model Controller")
			return
		}
		let semaphore = DispatchSemaphore(value: 0)
		let completion = { (error: NetworkError?) in
			if let error = error {
				XCTFail("There was an error: \(error)")
			}
			semaphore.signal()
		}

		// create
		let startCount = demoModelController.demoModels.count

		let startModel = demoModelController.create(modelWithTitle: "Test CRUD Cat", andSubtitle: "Super Cat", imageURL: imageURL, completion: completion)
		semaphore.wait()

		// read
		demoModelController.clearLocalModelCache()
		XCTAssertTrue(demoModelController.demoModels.count == 0)
		demoModelController.fetchDemoModels(completion: completion)
		semaphore.wait()

		let newCount = demoModelController.demoModels.count
		XCTAssertTrue(newCount > startCount)
		XCTAssertTrue(demoModelController.demoModels.contains(startModel))

		// update
		guard let updatedModel = demoModelController.update(model: startModel, withTitle: "Updated CRUD Cat", subtitle: "Updated Cat", imageURL: imageURL, completion: completion) else {
			XCTFail("Failed Updating Model")
			return
		}
		semaphore.wait()
		demoModelController.clearLocalModelCache()
		XCTAssertTrue(demoModelController.demoModels.count == 0)
		demoModelController.fetchDemoModels(completion: completion)
		semaphore.wait()

		XCTAssertTrue(demoModelController.demoModels.contains(updatedModel))
		XCTAssert(demoModelController.demoModels.contains(startModel) == false) // for some reason XCTAssertFalse was failing, but it was definitely false

		// delete
		let deleteCompletion = completion
		demoModelController.delete(model: updatedModel, completion: deleteCompletion)
		semaphore.wait()
		let deleteRefreshCompletion = completion
		demoModelController.fetchDemoModels(completion: deleteRefreshCompletion)
		semaphore.wait()

		XCTAssertFalse(demoModelController.demoModels.contains(updatedModel))
		XCTAssert(demoModelController.demoModels.contains(startModel) == false)
	}

}
