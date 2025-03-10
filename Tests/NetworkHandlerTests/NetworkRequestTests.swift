import Testing
import NetworkHandler
import TestSupport
import PizzaMacros

struct NetworkRequestTests {
	@Test func genericEncoding() async throws {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)

		let dummyURL = #URL("https://redeggproductions.com")
		let request = try dummyURL.downloadRequest.with {
			try $0.encodeData(testDummy)
		}

		let data = try #require(request.payload)

		let decoded = try DownloadEngineRequest.defaultDecoder.decode(DummyType.self, from: data)
		#expect(decoded == testDummy)
	}
}

//	/// Tests adding, setting, and getting header values
//	func testRequestHeaders() {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		var request = dummyURL.request
//
//		request.addValue(.json, forHTTPHeaderField: .contentType)
//		XCTAssertEqual("application/json", request.value(forHTTPHeaderField: .contentType))
//		request.setValue(.xml, forHTTPHeaderField: .contentType)
//		XCTAssertEqual("application/xml", request.value(forHTTPHeaderField: .contentType))
//		request.setValue("Bearer: 12345", forHTTPHeaderField: .authorization)
//		XCTAssertEqual(["Content-Type": "application/xml", "Authorization": "Bearer: 12345"], request.allHeaderFields)
//
//		request.setValue(nil, forHTTPHeaderField: .authorization)
//		XCTAssertEqual(["Content-Type": "application/xml"], request.allHeaderFields)
//		XCTAssertNil(request.value(forHTTPHeaderField: .authorization))
//
//		request.setValue("Arbitrary Value", forHTTPHeaderField: "Arbitrary Key")
//		XCTAssertEqual(["Content-Type": "application/xml", "arbitrary key": "Arbitrary Value"], request.allHeaderFields)
//
//		let allFields = [
//			"Content-Type": "application/xml",
//			"Authorization": "Bearer: 12345",
//			"Arbitrary Key": "Arbitrary Value",
//		]
//		request.allHeaderFields = allFields
//		XCTAssertEqual(allFields, request.allHeaderFields)
//
//		var request2 = dummyURL.request
//		request2.setValue(.audioMp4, forHTTPHeaderField: .contentType)
//		XCTAssertEqual("audio/mp4", request2.value(forHTTPHeaderField: .contentType))
//
//		request2.setContentType(.bmp)
//		XCTAssertEqual("image/bmp", request2.value(forHTTPHeaderField: .contentType))
//
//		request2.setAuthorization("Bearer asdlkqf")
//		XCTAssertEqual("Bearer asdlkqf", request2.value(forHTTPHeaderField: .authorization))
//	}
//
//	func testHeaderEquals() {
//		let contentKey = HTTPHeaderKey.contentType
//
//		let nilString: String? = nil
//
//		XCTAssertTrue("Content-Type" == contentKey)
//		XCTAssertTrue(contentKey == "Content-Type")
//		XCTAssertTrue("Content-Typo" != contentKey)
//		XCTAssertTrue(contentKey != "Content-Typo")
//		XCTAssertFalse(contentKey == nilString)
//
//		let gif = HTTPHeaderValue.gif
//
//		XCTAssertTrue("image/gif" == gif)
//		XCTAssertTrue(gif == "image/gif")
//		XCTAssertTrue("image/jif" != gif)
//		XCTAssertTrue(gif != "image/jif")
//		XCTAssertFalse(gif == nilString)
//	}
//
//	func testURLRequestMirroredProperties() {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		var request = dummyURL.request
//
//		request.cachePolicy = .returnCacheDataDontLoad
//		XCTAssertEqual(.returnCacheDataDontLoad, request.cachePolicy)
//		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
//		XCTAssertEqual(.reloadIgnoringLocalAndRemoteCacheData, request.cachePolicy)
//
//		XCTAssertEqual(dummyURL, request.url)
//		let otherURL = URL(string: "https://redeggproductions.com/otherURL")
//		request.url = otherURL
//		XCTAssertEqual(otherURL, request.url)
//
//		let dummyStream = InputStream(data: Data([1, 2, 3, 4, 5]))
//
//		XCTAssertEqual(.data(nil), request.payload)
//		request.payload = .inputStream(dummyStream)
//		XCTAssertEqual(.inputStream(dummyStream), request.payload)
//
//		let testData = Data(##"{"json": 42}"##.utf8)
//		request.payload = .data(testData)
//		XCTAssertEqual(.data(testData), request.payload)
//		XCTAssertNotEqual(.inputStream(dummyStream), request.payload)
//		XCTAssertNotEqual(.upload(.data(testData)), request.payload)
//
//		request.payload = .upload(.data(testData))
//		XCTAssertEqual(.upload(.data(testData)), request.payload)
//		XCTAssertNotEqual(.data(testData), request.payload)
//
//		let fakeURL = URL(fileURLWithPath: "/Users/mememe/myfile.txt")
//		request.payload = .upload(.localFile(fakeURL))
//		XCTAssertNotEqual(.upload(.data(testData)), request.payload)
//		XCTAssertNotEqual(.data(testData), request.payload)
//		XCTAssertEqual(.upload(.localFile(fakeURL)), request.payload)
//
//		XCTAssertNil(request.mainDocumentURL)
//		request.mainDocumentURL = dummyURL
//		XCTAssertEqual(dummyURL, request.mainDocumentURL)
//
//		XCTAssertEqual(60, request.timeoutInterval)
//		request.timeoutInterval = 120
//		XCTAssertEqual(120, request.timeoutInterval)
//
//		request.httpShouldHandleCookies = false
//		XCTAssertFalse(request.httpShouldHandleCookies)
//		request.httpShouldHandleCookies = true
//		XCTAssertTrue(request.httpShouldHandleCookies)
//
//		request.httpShouldUsePipelining = false
//		XCTAssertFalse(request.httpShouldUsePipelining)
//		request.httpShouldUsePipelining = true
//		XCTAssertTrue(request.httpShouldUsePipelining)
//
//		request.allowsCellularAccess = false
//		XCTAssertFalse(request.allowsCellularAccess)
//		request.allowsCellularAccess = true
//		XCTAssertTrue(request.allowsCellularAccess)
//
//		request.networkServiceType = .avStreaming
//		XCTAssertEqual(.avStreaming, request.networkServiceType)
//		request.networkServiceType = .responsiveData
//		XCTAssertEqual(.responsiveData, request.networkServiceType)
//
//		#if !os(Linux)
//		request.allowsExpensiveNetworkAccess = false
//		XCTAssertFalse(request.allowsExpensiveNetworkAccess)
//		request.allowsExpensiveNetworkAccess = true
//		XCTAssertTrue(request.allowsExpensiveNetworkAccess)
//
//		request.allowsConstrainedNetworkAccess = false
//		XCTAssertFalse(request.allowsConstrainedNetworkAccess)
//		request.allowsConstrainedNetworkAccess = true
//		XCTAssertTrue(request.allowsConstrainedNetworkAccess)
//		#endif
//	}
//
//	func testPriority() async throws {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		// setup
//		let networkHandler = generateNetworkHandlerInstance()
//		let demoModel = ["model": "is gud"]
//		let mockData = try JSONEncoder().encode(demoModel)
//		await NetworkHandlerMocker.addMock(for: dummyURL, method: .get, data: mockData, code: 200)
//
//		let dlDelegate = TestingDelegate()
//
//		let defaultRequest = dummyURL.request
//		Task {
//			try await networkHandler.transferMahDatas(for: defaultRequest, delegate: dlDelegate)
//		}
//		try await wait(forArbitraryCondition: dlDelegate.task != nil)
//		let defTask = (await networkHandler.defaultSession.allTasks).first { $0.originalRequest == defaultRequest.urlRequest }
//		XCTAssertEqual(defTask?.priority, defaultRequest.priority.rawValue)
//		dlDelegate.task?.cancel()
//		dlDelegate.task = nil
//		try await wait(forArbitraryCondition: (await networkHandler.defaultSession.allTasks).isEmpty)
//
//		var highRequest = dummyURL.request
//		highRequest.priority = .highPriority
//		Task { [highRequest] in
//			try await networkHandler.transferMahDatas(for: highRequest, delegate: dlDelegate)
//		}
//		try await wait(forArbitraryCondition: dlDelegate.task != nil)
//		let highTask = (await networkHandler.defaultSession.allTasks).first { $0.originalRequest == highRequest.urlRequest }
//		XCTAssertEqual(highTask?.priority, highRequest.priority.rawValue)
//		dlDelegate.task?.cancel()
//		dlDelegate.task = nil
//		try await wait(forArbitraryCondition: (await networkHandler.defaultSession.allTasks).isEmpty)
//
//		var lowRequest = dummyURL.request
//		lowRequest.priority = .lowPriority
//
//		Task { [lowRequest] in
//			try await networkHandler.transferMahDatas(for: lowRequest, delegate: dlDelegate)
//		}
//		try await wait(forArbitraryCondition: dlDelegate.task != nil)
//		let lowTask = (await networkHandler.defaultSession.allTasks).first { $0.originalRequest == lowRequest.urlRequest }
//		XCTAssertEqual(lowTask?.priority, lowRequest.priority.rawValue)
//		dlDelegate.task?.cancel()
//		dlDelegate.task = nil
//		try await wait(forArbitraryCondition: (await networkHandler.defaultSession.allTasks).isEmpty)
//
//		var arbitraryRequest = dummyURL.request
//		arbitraryRequest.priority = -1
//		XCTAssertEqual(0, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 0
//		XCTAssertEqual(0, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 0.4
//		XCTAssertEqual(0.4, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 1
//		XCTAssertEqual(1, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 4
//		XCTAssertEqual(1, arbitraryRequest.priority.rawValue)
//	}
//
//	func testRequestID() throws {
//		let dummyURL = #URL("https://redeggproductions.com")
//
//		var noID = dummyURL.request
//		XCTAssertNil(noID.requestID)
//
//		NetworkRequest.automaticallyAddRequestID = true
//		noID = dummyURL.request
//		XCTAssertNotNil(noID.requestID)
//
//		NetworkRequest.automaticallyAddRequestID = false
//		noID = dummyURL.request
//		XCTAssertNil(noID.requestID)
//	}
//}
