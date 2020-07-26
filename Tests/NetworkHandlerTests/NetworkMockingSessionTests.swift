//
//  NetworkMockingSessionTests.swift
//  NetworkHandler
//
//  Created by Michael Redig on 5/10/20.
//  Copyright © 2020 Red_Egg Productions. All rights reserved.
//

import XCTest
import NetworkHandler

class NetworkMockingSessionTests: XCTestCase {

	let url1 = URL(string: "https://fakeurl.com/webresource1")
	let url2 = URL(string: "https://fakeurl.com/webresource2")

	let resource1 = Data([1, 2, 3, 4, 5])
	let resource2 = Data([5, 4, 3, 2, 1])

	lazy var webSources = [url1: resource1, url2: resource2]

	func createMockSession() -> NetworkMockingSession {
		let mockSession = NetworkMockingSession { [self] request -> (Data?, Int, Error?) in
			guard let resource = self.webSources[request.url] else {
				return (nil, 404, nil)
			}
			return (resource, 200, nil)
		}
		return mockSession
	}

	/// Tests the server side simulator closure to make sure it correctly runs
	func testServerSideSimulatorSuccess() {
		let networkHandler = NetworkHandler()

		let waitForMocking = expectation(description: "Wait for mocking")

		let mockSession = createMockSession()

		let dummyURL = url1!

		var theResult: Result<Data, NetworkError>?
		let handle = networkHandler.transferMahDatas(with: dummyURL.request, session: mockSession) { result in
			theResult = result
			waitForMocking.fulfill()
		}

		wait(for: [waitForMocking], timeout: 10)

		XCTAssertNoThrow(try theResult?.get())
		XCTAssertEqual(resource1, try theResult?.get())
		XCTAssertEqual(handle.status, .completed)
	}

	/// Tests the server side simulator closure - more of a demo than really testing anything
	func testServerSideSimulatorFailed() {
		let networkHandler = NetworkHandler()

		let waitForMocking = expectation(description: "Wait for mocking")

		let mockSession = createMockSession()

		let dummyURL = URL(string: "https://fakeurl.com/webresource/nonexisting")!

		var theResult: Result<Data, NetworkError>?
		networkHandler.transferMahDatas(with: dummyURL.request, session: mockSession) { result in
			theResult = result
			waitForMocking.fulfill()
		}

		wait(for: [waitForMocking], timeout: 10)

		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
			XCTAssertEqual(NetworkError.httpNon200StatusCode(code: 404, data: nil), error as? NetworkError)
		}
	}

	/// Tests NetworkDataTask cancel function
	func testCancelLoading() {
		let networkHandler = NetworkHandler()

		var mockSession = createMockSession()
		mockSession.mockDelay = 0.5

		let dummyURL = URL(string: "https://fakeurl.com/webresource/nonexisting")!

		var theResult: Result<Data, NetworkError>?
		let handle = networkHandler.transferMahDatas(with: dummyURL.request, session: mockSession) { result in
			theResult = result
		}
		XCTAssertEqual(handle.status, .running)
		handle.cancel()

		sleep(1)

		XCTAssertNil(theResult)
		XCTAssertEqual(handle.status, .canceling)
	}

	/// Tests NetworkMockingSession in the scenario of a url request with no url
	func testNoURLForMock() {
		let mockingSession = NetworkMockingSession(mockData: resource1, mockError: nil)

		var urlRequest = URLRequest(url: url1!)
		urlRequest.url = nil

		let waitForMocking = expectation(description: "wait for mocking")

		var output: (Data?, URLResponse?, Error?)?
		mockingSession.loadData(with: urlRequest) { data, response, error in
			output = (data, response, error)
			waitForMocking.fulfill()
		}.resume()

		wait(for: [waitForMocking], timeout: 10)

		XCTAssertNil(output?.0)
		XCTAssertNil(output?.1)
		XCTAssertNil(output?.2)
	}
}
