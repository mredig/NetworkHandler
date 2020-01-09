//
//  NetworkHandlerTests.swift
//  NetworkHandlerTests
//
//  Created by Michael Redig on 5/29/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import XCTest
@testable import NetworkHandler

#if os(macOS)
typealias TestImage = NSImage
#elseif os(iOS)
typealias TestImage = UIImage
#else
#endif

/// Obviously dependent on network conditions
class NetworkHandlerTests: XCTestCase {

	var demoModelController: DemoModelController?
	let imageURL = URL(string: "https://placekitten.com/300/300")!

	override func setUp() {
		super.setUp()
		demoModelController = DemoModelController()
	}

	func testImageDownloadAndCache() {
		let waitForInitialDownload = expectation(description: "Waiting for things")
		let networkHandler = NetworkHandler()

		var image: TestImage?
		let networkStart = CFAbsoluteTimeGetCurrent()
		networkHandler.transferMahDatas(with: imageURL.request, usingCache: true) { (result: Result<Data, NetworkError>) in
			do {
				let imageData = try result.get()
				image = TestImage(data: imageData)
			} catch {
				XCTFail("Failed getting image data: \(error)")
			}
			waitForInitialDownload.fulfill()
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for download: \(error)")
			}
		}
		let networkFinish = CFAbsoluteTimeGetCurrent()

		// now try retrieving from cache
		var imageTwo: TestImage?
		let waitForCacheLoad = expectation(description: "Watiting for cache")
		let cacheStart = CFAbsoluteTimeGetCurrent()
		networkHandler.transferMahDatas(with: imageURL.request, usingCache: true) { (result: Result<Data, NetworkError>) in
			do {
				let imageData = try result.get()
				imageTwo = TestImage(data: imageData)
			} catch {
				XCTFail("Failed getting image data: \(error)")
			}
			waitForCacheLoad.fulfill()
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for download: \(error)")
			}
		}
		let cacheFinish = CFAbsoluteTimeGetCurrent()

		let networkDuration = networkFinish - networkStart
		let cacheDuration = cacheFinish - cacheStart
		let cacheRatio = cacheDuration / networkDuration
		print("netDuration: \(networkDuration)\ncacheDuration: \(cacheDuration)\ncache took \(cacheRatio)x as long")

		let imageOneData = image?.pngData()
		let imageTwoData = imageTwo?.pngData()
		XCTAssertNotNil(imageOneData)
		XCTAssertNotNil(imageTwoData)
		XCTAssertEqual(imageOneData, imageTwoData, "hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)")
	}

	func testMockDataSuccess() {
		let networkHandler = NetworkHandler()
		let waitForMocking = expectation(description: "Wait for mocking")

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		let mockData = {
			try? JSONEncoder().encode(demoModel)
		}()
		let mockSession = NetworkMockingSession(mockData: mockData, mockError: nil)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			do {
				let model = try result.get()
				XCTAssertEqual(model, demoModel)
			} catch {
				XCTFail("Error getting mock data: \(error)")
			}
			waitForMocking.fulfill()
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func allErrorCases() -> [NetworkError] {
		let dummyError = NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil)
		let allErrorCases: [NetworkError] = [.badData(sourceData: nil),
											 .databaseFailure(specifically: dummyError),
											 .dataCodingError(specifically: dummyError, sourceData: nil),
											 .dataWasNull,
											 .httpNon200StatusCode(code: 404, data: nil),
											 .imageDecodeError,
											 .noStatusCodeResponse,
											 .otherError(error: dummyError),
											 .urlInvalid(urlString: "he.ho.hum")]
		return allErrorCases
	}

	func testMockDataErrors() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")


		var allErrors: [Error] = allErrorCases()
		allErrors.append(NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil))

		for testingError in allErrors {
			let waitForMocking = expectation(description: "Wait for mocking")
			let mockSession = NetworkMockingSession(mockData: nil, mockError: testingError)

			networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
				defer {
					waitForMocking.fulfill()
				}
				do {
					_ = try result.get()
				} catch {
					guard let netError = error as? NetworkError else {
						XCTFail("Didn't wrap error correctly: \(error)")
						return
					}
					if let testingError = testingError as? NetworkError {
						XCTAssertEqual(testingError, netError)
					} else if case NetworkError.otherError(error: let otherError) = netError {
						XCTAssertEqual(testingError.localizedDescription, otherError.localizedDescription)
					} else {
						XCTFail("Something went wrong: \(error) \(testingError)")
					}
				}
			}
			waitForExpectations(timeout: 10) { error in
				if let error = error {
					XCTFail("Timed out waiting for mocking: \(error)")
				}
			}
		}
	}

	func testMock404Response() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let waitForMocking = expectation(description: "Wait for mocking")
		let mockSession = NetworkMockingSession(mockData: nil, mockError: nil, mockResponseCode: 404)

		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
				XCTFail("no error was thrown")
			} catch {
				guard case NetworkError.httpNon200StatusCode(code: 404, data: nil) = error else {
					XCTFail("Recieved unexpected error: \(error)")
					return
				}
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testMock404ResponseStrict() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let waitForMocking = expectation(description: "Wait for mocking")
		let mockSession = NetworkMockingSession(mockData: nil, mockError: nil, mockResponseCode: 404)

		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...299)
		networkHandler.transferMahCodableDatas(with: request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
				XCTFail("no error was thrown")
			} catch {
				guard case NetworkError.httpNon200StatusCode(code: 404, data: nil) = error else {
					XCTFail("Recieved unexpected error: \(error)")
					return
				}
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testMockGraphQLError() {
		let networkHandler = NetworkHandler()
		networkHandler.graphQLErrorSupport = true

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!

		let waitForMocking = expectation(description: "Wait for mocking")

		let exception = GQLErrorException(errno: -2, code: "RANDERR", syscall: nil, path: nil, stacktrace: ["Errrrrrrrroooooooooooorrrrrr"])
		let theExtension = GQLErrorExtension(code: "INTERNAL_SERVER_ERROR", exception: exception)
		let mockDataModel = GQLError(message: "Test error", path: nil, locations: nil, extensions: theExtension)

		let mockData = try? JSONEncoder().encode(["errors": [mockDataModel]])

		let mockSession = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 200)

		var request = dummyBaseURL.request
		request.expectedResponseCodes = 200
		networkHandler.transferMahCodableDatas(with: request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
				XCTFail("no error was thrown")
			} catch NetworkError.graphQLError(let gqlError) {
				XCTAssertEqual(mockDataModel, gqlError)
				return
			} catch {
				XCTFail("Recieved unexpected error: \(error)")
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	/// This test will only work so long as my school project is live and conforming. Would be better to make a
	/// permanent test server to test this with.
	func testGraphQLError() {
		let networkHandler = NetworkHandler()
		networkHandler.graphQLErrorSupport = true

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let baseURL = URL(string: "https://lambda-labs-swaap-staging.herokuapp.com/")!

		let waitForMocking = expectation(description: "Wait for mocking")

		var request = baseURL.request

		request.expectedResponseCodes.insertRange(0...1000)
		request.httpMethod = .post
		request.addValue(.contentType(type: .json), forHTTPHeaderField: .commonKey(key: .contentType))
		request.httpBody = ##"{ "query": "{ userss { id authId name } }" }"##.data(using: .utf8)

		networkHandler.transferMahCodableDatas(with: request) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
				XCTFail("no error was thrown")
			} catch NetworkError.graphQLError(let gqlError) {
				XCTAssertEqual(##"Cannot query field "userss" on type "Query". Did you mean "user"?"##, gqlError.message)
				XCTAssertEqual("GRAPHQL_VALIDATION_FAILED", gqlError.extensions.code)
				return
			} catch {
				XCTFail("Recieved unexpected error: \(error)")
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testErrorEquatable() {
		let allErrors = allErrorCases()
		let dupErrors = allErrorCases()
		var rotErrors = allErrorCases()
		let rot1 = rotErrors.remove(at: 0)
		rotErrors.append(rot1)

		for (index, error) in allErrors.enumerated() {
			XCTAssertEqual(error, dupErrors[index])
			XCTAssertNotEqual(error, rotErrors[index])
		}
	}

	func testRespect200Strict200() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = {
			try? JSONEncoder().encode(demoModel)
		}()
		let mockSession200 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 200)

		let waitForMocking = expectation(description: "Wait for mocking")
		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...299)
		networkHandler.transferMahCodableDatas(with: request, session: mockSession200) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				let model = try result.get()
				XCTAssertEqual(model, demoModel)
			} catch {
				XCTFail("an error occured: \(error)")
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testRespect200Strict202() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = {
			try? JSONEncoder().encode(demoModel)
		}()
		let mockSession202 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 202)

		let waitForMocking = expectation(description: "Wait for mocking")
		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...299)
		networkHandler.transferMahCodableDatas(with: request, session: mockSession202) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
			} catch {
				guard case NetworkError.httpNon200StatusCode(code: 202, data: mockData) = error else {
					XCTFail("Recieved unexpected error: \(error)")
					return
				}
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testRespect200NotStrict200() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = {
			try? JSONEncoder().encode(demoModel)
		}()
		let mockSession200 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 200)

		let waitForMocking = expectation(description: "Wait for mocking")
		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...299)
		networkHandler.transferMahCodableDatas(with: request, session: mockSession200) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				let model = try result.get()
				XCTAssertEqual(model, demoModel)
			} catch {
				XCTFail("an error occured: \(error)")
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testRespect200NotStrict202() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = {
			try? JSONEncoder().encode(demoModel)
		}()
		let mockSession202 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 202)

		let waitForMocking = expectation(description: "Wait for mocking")
		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...299)
		networkHandler.transferMahCodableDatas(with: request, session: mockSession202) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				let model = try result.get()
				XCTAssertEqual(model, demoModel)
			} catch {
				XCTFail("an error occured: \(error)")
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testNullData() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockSession = NetworkMockingSession(mockData: "null".data(using: .utf8), mockError: nil)

		let waitForMocking = expectation(description: "Wait for mocking")
		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
			} catch {
				guard case NetworkError.dataWasNull = error else {
					XCTFail("got unexpected error: \(error)")
					return
				}
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testBadData() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = {
			try? JSONEncoder().encode(demoModel)[0...20]
		}()
		let mockSession = NetworkMockingSession(mockData: mockData, mockError: nil)

		let waitForMocking = expectation(description: "Wait for mocking")
		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
			} catch {
				guard case NetworkError.dataCodingError(specifically: _) = error else {
					XCTFail("got unexpected error: \(error)")
					return
				}
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}

	func testNoData() {
		let networkHandler = NetworkHandler()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockSession = NetworkMockingSession(mockData: nil, mockError: nil)

		let waitForMocking = expectation(description: "Wait for mocking")
		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			defer {
				waitForMocking.fulfill()
			}
			do {
				_ = try result.get()
			} catch {
				guard case NetworkError.badData = error else {
					XCTFail("got unexpected error: \(error)")
					return
				}
			}
		}
		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("Timed out waiting for mocking: \(error)")
			}
		}
	}
}
