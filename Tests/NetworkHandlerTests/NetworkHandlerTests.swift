//
//  NetworkHandlerTests.swift
//  NetworkHandlerTests
//
//  Created by Michael Redig on 5/29/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//
//swiftlint:disable type_body_length

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

	// MARK: - Properties
	var demoModelController: DemoModelController?
	let imageURL = URL(string: "https://placekitten.com/300/300")!

	// MARK: - Lifecycle
	override func setUp() {
		super.setUp()
		demoModelController = DemoModelController()
	}

	// MARK: - Live Network Tests
	/// Tests downloading over a live connection, caching the download, and subsequently downloading the cached file.
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

	/// Tests using a Mock Session that is successful.
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

	/// Tests using a Mock session that checks a multitude of errors, also confirming that normal errors are wrapped in a NetworkError properly
	func testMockDataErrors() {
		let networkHandler = NetworkHandler()

		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")


		var allErrors: [Error] = NetworkError.allErrorCases()
		allErrors.append(NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil))

		for originalError in allErrors {
			let waitForMocking = expectation(description: "Wait for mocking")
			let mockSession = NetworkMockingSession(mockData: nil, mockError: originalError)

			var theResult: Result<DemoModel, NetworkError>?
			networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
				theResult = result
				waitForMocking.fulfill()
			}

			wait(for: [waitForMocking], timeout: 10)

			XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
				guard let netError = error as? NetworkError else {
					XCTFail("Didn't wrap error correctly: \(error)")
					return
				}

				// most of the original errors to test against are already a NetworkError. One is just a regular, error
				// though, so the followup case is to confirm that it was properly wrapped after going through NetworkHandler's transfer
				if let expectedError = originalError as? NetworkError {
					XCTAssertEqual(expectedError, netError)
				} else if case NetworkError.otherError(error: let otherError) = netError {
					XCTAssertEqual(originalError.localizedDescription, otherError.localizedDescription)
				} else {
					XCTFail("Something went wrong: \(error) \(originalError)")
				}
			}
		}
	}

	/// Tests a Mock session giving a 404 response code
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

		var theResult: Result<DemoModel, NetworkError>?
		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			theResult = result
			waitForMocking.fulfill()
		}

		wait(for: [waitForMocking], timeout: 10)
		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
			let expectedError = NetworkError.httpNon200StatusCode(code: 404, data: nil)
			XCTAssertEqual(expectedError, error as? NetworkError)
		}
	}

	/// Tests (using a Mock session) receiving a GraphQL error from the server.
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
		var theResult: Result<DemoModel, NetworkError>?
		networkHandler.transferMahCodableDatas(with: request, session: mockSession) { (result: Result<DemoModel, NetworkError>) in
			theResult = result
			waitForMocking.fulfill()
		}

		wait(for: [waitForMocking], timeout: 10)
		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
			let expectedError = NetworkError.graphQLError(error: mockDataModel)
			XCTAssertEqual(expectedError, error as? NetworkError)
		}
	}

	/// Tests a live server with GraphQL.
	///
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

		var theResult: Result<DemoModel, NetworkError>?
		networkHandler.transferMahCodableDatas(with: request) { (result: Result<DemoModel, NetworkError>) in
			theResult = result
			waitForMocking.fulfill()
		}
		wait(for: [waitForMocking], timeout: 10)

		XCTAssertThrowsError(try theResult?.get(), "No error when error was expected") { error in
			guard case NetworkError.graphQLError(error: let gqlError) = error else {
				XCTFail("Got an unexpected error from server: \(error)")
				return
			}
			XCTAssertEqual(##"Cannot query field "userss" on type "Query". Did you mean "user"?"##, gqlError.message)
			XCTAssertEqual("GRAPHQL_VALIDATION_FAILED", gqlError.extensions.code)
		}
	}

	/// Tests that when expecting ONLY a 200 response code, a 200 code will be an expected success
	func testRespect200OnlyAndGet200() {
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
		request.expectedResponseCodes = 200

		var theResult: Result<DemoModel, NetworkError>?
		networkHandler.transferMahCodableDatas(with: request, session: mockSession200) { (result: Result<DemoModel, NetworkError>) in
			theResult = result
			waitForMocking.fulfill()
		}
		wait(for: [waitForMocking], timeout: 10)

		XCTAssertNoThrow(try theResult?.get())
		XCTAssertEqual(try theResult?.get(), demoModel)
	}

	/// Tests that when expecting ONLY a 200 response code, even a 202 code will cause an error to be thrown
	func testRespect200OnlyButGet202() {
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
		request.expectedResponseCodes = 200
		var theResult: Result<DemoModel, NetworkError>?
		networkHandler.transferMahCodableDatas(with: request, session: mockSession202) { (result: Result<DemoModel, NetworkError>) in
			theResult = result
			waitForMocking.fulfill()
		}

		wait(for: [waitForMocking], timeout: 10)

		XCTAssertThrowsError(try theResult?.get(), "Got unexpected error") { error in
			XCTAssertEqual(NetworkError.httpNon200StatusCode(code: 202, data: mockData), error as? NetworkError)
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

	func testEncodingGeneric() {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)

		let dummyURL = URL(string: "https://redeggproductions.com")!
		var request = dummyURL.request

		request.encodeData(testDummy)

		guard let requestData = request.httpBody else {
			XCTFail("No httpBody")
			return
		}
		
		do {
			let reconstructedDummy = try request.decoder.decode(DummyType.self, from: requestData)
			XCTAssertEqual(testDummy, reconstructedDummy)
		} catch {
			XCTFail("Can't decode dummy data")
			return
		}
	}

	struct DummyType: Codable, Equatable {
		let id: Int
		let value: String
		let other: Double
	}

	@available(iOS 11.0, macOS 13.0, *)
	func testErrorOutput() {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		let testData = try? encoder.encode(testDummy)

		var error = NetworkError.badData(sourceData: testData)
		let testString = String(data: testData!, encoding: .utf8)!
		let error1Str = "NetworkError: BadData (\(testString))"

		XCTAssertEqual(error1Str, error.debugDescription)

		error = .httpNon200StatusCode(code: 401, data: testData)
		let error2Str = "NetworkError: Bad Response Code (401) with data: \(testString)"
		XCTAssertEqual(error2Str, error.debugDescription)

		error = .badData(sourceData: nil)
		let error3Str = "NetworkError: BadData (nil value)"
		XCTAssertEqual(error3Str, error.debugDescription)
	}
}
