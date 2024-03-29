import XCTest
@testable import NetworkHandler
import Crypto
import TestSupport
import Swiftwood
import PizzaMacros

/// Obviously dependent on network conditions
class NetworkHandlerTests: NetworkHandlerBaseTest {

	// MARK: - Properties
	var demoModelController: DemoModelController?
	let imageURL = #URL("https://s3.wasabisys.com/network-handler-tests/images/IMG_2932.jpg")

	// MARK: - Lifecycle
	override func setUp() {
		super.setUp()
		demoModelController = DemoModelController()

		let consoleDest = ConsoleLogDestination(maxBytesDisplayed: -1)
		consoleDest.minimumLogLevel = .veryVerbose
		log.appendDestination(consoleDest)
	}

	override func tearDown() {
		super.tearDown()

		log.clearDestinations()
	}

	func testMassiveNumberOfConnections() async throws {
		var urls: [URL] = []
		for x in 1...10 {
			for y in 1...10 {
				urls.append(URL(string: "https://placekitten.com/\((x * 10) + 99)/\((y * 10) + 99)")!)
			}
		}

		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let config = URLSessionConfiguration.ephemeral
		config.urlCache = nil
		config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		let allData = try await withThrowingTaskGroup(of: Data.self, body: { group -> [Data] in
			urls.forEach { url in
				group.addTask {
					var request = url.request
					request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
					return try await networkHandler
						.transferMahDatas(
							for: url.request,
							usingCache: .dontUseCache,
							sessionConfiguration: config)
						.data
				}
			}

			var completed: [Data] = []
			for try await kitten in group {
				completed.append(kitten)
			}
			return completed
		})

		XCTAssertEqual(100, allData.count)
	}

	// MARK: - Live Network Tests
	/// Tests downloading over a live connection, caching the download, and subsequently loading the file from cache.
	func testImageDownloadAndCache() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		// completely disabling cache and creating a new url session with each request isn't strictly or even typically
		// necessary. This is done just to absolutely confirm the test is working.
		let config = URLSessionConfiguration.ephemeral
		config.urlCache = nil
		config.requestCachePolicy = .reloadIgnoringCacheData

		let networkStart = CFAbsoluteTimeGetCurrent()
		let image1Result = try await networkHandler
			.transferMahDatas(
				for: imageURL.request,
				usingCache: .key("kitten"),
				sessionConfiguration: config)
		let networkFinish = CFAbsoluteTimeGetCurrent()

		// now try retrieving from cache
		let cacheStart = CFAbsoluteTimeGetCurrent()
		let image2Result = try await networkHandler
			.transferMahDatas(
				for: imageURL.request,
				usingCache: .key("kitten"),
				sessionConfiguration: config)
		let cacheFinish = CFAbsoluteTimeGetCurrent()

		// calculate cache speed improvement, just for funsies
		let networkDuration = networkFinish - networkStart
		let cacheDuration = cacheFinish - cacheStart
		let cacheRatio = cacheDuration / networkDuration

		let formatter = NumberFormatter()
		formatter.maximumFractionDigits = 6
		let netDurationStr = formatter.string(from: networkDuration as NSNumber) ?? "nan"
		let cacheDurationStr = formatter.string(from: cacheDuration as NSNumber) ?? "nan"
		let cacheRatioStr = formatter.string(from: cacheRatio as NSNumber) ?? "nan"
		print("netDuration: \(netDurationStr)\ncacheDuration: \(cacheDurationStr)\ncache took \(cacheRatioStr)x as long")
		XCTAssertLessThan(
			cacheDuration,
			networkDuration * 0.5,
			"The cache lookup wasn't even twice as fast as the original lookup. It's possible the cache isn't working")

		let imageOneData = image1Result.data
		let imageTwoData = image2Result.data
		XCTAssertEqual(imageOneData, imageTwoData, "hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)")

		XCTAssertNotNil(TestImage(data: imageOneData))
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	// MARK: - Mock Network Tests
	/// Tests using a Mock Session that is successful.
	func testMockDataSuccess() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		let mockData = try JSONEncoder().encode(demoModel)

		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 200)

		let result: DemoModel = try await networkHandler.transferMahCodableDatas(for: dummyModelURL.request).decoded
		XCTAssertEqual(demoModel, result)
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	func testDataAsCodable() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		// expected result
		let demoData = Data([1, 2, 3, 4, 5, 6])

		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("jpg")

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: demoData, code: 200)

		let result: Data = try await networkHandler.transferMahCodableDatas(for: dummyModelURL.request).decoded
		XCTAssertEqual(demoData, result)
	}

//	/// Tests using a Mock session that checks a multitude of errors, also confirming that normal errors are wrapped in
//	/// a NetworkError properly
//	func testMockDataErrors() {
//		let networkHandler = generateNetworkHandlerInstance()
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//
//		var allErrors: [Error] = NetworkError.allErrorCases()
//		allErrors.append(NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil))
//
//		for originalError in allErrors {
//			let waitForMocking = expectation(description: "Wait for mocking")
//			let mockSession = NetworkMockingSession(mockData: nil, mockError: originalError)
//
//			var theResult: Result<DemoModel, Error>?
//			networkHandler
//				.transferMahCodableDatas(
//					with: dummyModelURL.request,
//					session: mockSession
//				) { (result: Result<DemoModel, Error>) in
//					theResult = result
//					waitForMocking.fulfill()
//				}
//
//			wait(for: [waitForMocking], timeout: 10)
//
//			XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
//				guard let netError = error as? NetworkError else {
//					XCTFail("Didn't wrap error correctly: \(error)")
//					return
//				}
//
//				// most of the original errors to test against are already a NetworkError. One is just a regular, error
//				// though, so the followup case is to confirm that it was properly wrapped after going through
//				// NetworkHandler's transfer
//				if let expectedError = originalError as? NetworkError {
//					XCTAssertEqual(expectedError, netError)
//				} else if case NetworkError.otherError(error: let otherError) = netError {
//					XCTAssertEqual(originalError.localizedDescription, otherError.localizedDescription)
//				} else {
//					XCTFail("Something went wrong: \(error) \(originalError)")
//				}
//			}
//		}
//	}

	/// Tests a Mock session giving a 404 response code
	func testMock404ResponseDeliberatelySet() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: Data([1]), code: 404)

		let task = Task { () -> DemoModel in
			try await networkHandler.transferMahCodableDatas(for: dummyModelURL.request).decoded
		}
		let theResult = await task.result

		XCTAssertThrowsError(try theResult.get(), "No error when error expected") { error in
			let expectedError = NetworkError.httpNon200StatusCode(
				code: 404,
				originalRequest: dummyModelURL.request,
				data: Data([1]))
			XCTAssertEqual(expectedError, error as? NetworkError)
		}
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	/// Tests a Mock session giving a 404 response code
	func testMock404Response() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let task = Task { () -> DemoModel in
			try await networkHandler.transferMahCodableDatas(for: dummyModelURL.request).decoded
		}
		let theResult = await task.result

		XCTAssertThrowsError(try theResult.get(), "No error when error expected") { error in
			let expectedError = NetworkError.httpNon200StatusCode(
				code: 404,
				originalRequest: dummyModelURL.request,
				data: Data())
			XCTAssertEqual(expectedError, error as? NetworkError)
		}
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	/// Tests using a mock session that when expecting ONLY a 200 response code, a 200 code will be an expected success
	func testRespect200OnlyAndGet200() async throws {

		let networkHandler = generateNetworkHandlerInstance()
		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = try JSONEncoder().encode(demoModel)

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 200)

		var request = dummyModelURL.request
		request.expectedResponseCodes = 200

		let result: DemoModel = try await networkHandler.transferMahCodableDatas(for: request).decoded
		XCTAssertEqual(demoModel, result)
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	/// Tests using a Mock session that when expecting ONLY a 200 response code, even a 202 code will 
	/// cause an error to be thrown
	func testRespect200OnlyButGet202() async throws {
		let networkHandler = generateNetworkHandlerInstance()
		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = try JSONEncoder().encode(demoModel)

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 202)

		var request = dummyModelURL.request
		request.expectedResponseCodes = 200

		let task = Task { [request] () -> DemoModel in
			try await networkHandler.transferMahCodableDatas(for: request).decoded
		}

		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Got unexpected error") { error in
			XCTAssertEqual(
				NetworkError.httpNon200StatusCode(code: 202, originalRequest: request, data: mockData),
				error as? NetworkError)
		}
	}

	/// Tests using a mock session that expected response ranges are respsected
	func testRespectResponseRangeGetValidResponse() async throws {
		let networkHandler = generateNetworkHandlerInstance()
		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = try JSONEncoder().encode(demoModel)

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 200)

		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...299)
		let result: DemoModel = try await networkHandler.transferMahCodableDatas(for: request).decoded

		XCTAssertEqual(demoModel, result)
	}

	/// Tests using a mock session that values outside the expected response ranges are thrown
	func testRespectResponseRangeGetInvalidResponse() async throws {
		let networkHandler = generateNetworkHandlerInstance()
		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = try JSONEncoder().encode(demoModel)

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 202)

		var request = dummyModelURL.request
		request.expectedResponseCodes.insertRange(200...201)

		let task = Task { [request] () -> DemoModel in
			try await networkHandler.transferMahCodableDatas(for: request).decoded
		}
		let result = await task.result

		XCTAssertThrowsError(try result.get(), "No error when error expected") { error in
			let expectedError = NetworkError.httpNon200StatusCode(code: 202, originalRequest: request, data: mockData)
			XCTAssertEqual(expectedError, error as? NetworkError)
		}
	}

	func testUploadViaBGSession() async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			XCTFail("Need s3 credentials")
			return
		}

		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 5

		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		try generateRandomBytes(in: dummyFile, megabytes: sizeOfUploadMB)

		let dataHash = try fileHash(dummyFile)

		let awsHeaderInfo = try AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: "\(dataHash.toHexString())")
		request = try awsHeaderInfo.processRequest(request)

		request.payload = .upload(.localFile(dummyFile))

		addTeardownBlock {
			try? FileManager.default.removeItem(at: dummyFile)
		}

		let id = UUID().uuidString
		let config = URLSessionConfiguration.background(withIdentifier: id)

		_ = try await networkHandler.transferMahDatas(for: request, sessionConfiguration: config)

		let dlRequest = url.request
		let downloadedResult = try await networkHandler.transferMahDatas(for: dlRequest)
		XCTAssertEqual(SHA256.hash(data: downloadedResult.data), dataHash)
		try checkNetworkHandlerTasksFinished(networkHandler)

	}

	func testUploadFile() async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			XCTFail("Need s3 credentials")
			return
		}

		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 5

		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		try generateRandomBytes(in: dummyFile, megabytes: sizeOfUploadMB)

		let dataHash = try fileHash(dummyFile)

		let awsHeaderInfo = try AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(dataHash))
		request = try awsHeaderInfo.processRequest(request)

		request.payload = .upload(.localFile(dummyFile))

		addTeardownBlock {
			try? FileManager.default.removeItem(at: dummyFile)
		}

		_ = try await networkHandler.transferMahDatas(for: request)

		let dlRequest = url.request

		let downloadedResult = try await networkHandler.transferMahDatas(for: dlRequest)
		XCTAssertEqual(SHA256.hash(data: downloadedResult.data), dataHash)
		try checkNetworkHandlerTasksFinished(networkHandler)
	}

	func testUploadMultipartFile() async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			XCTFail("Need s3 credentials")
			return
		}

		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 10

		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		defer { try? FileManager.default.removeItem(at: dummyFile) }
		try generateRandomBytes(in: dummyFile, megabytes: sizeOfUploadMB)

		let boundary = "asdlfkjasdf"
		let multipart = MultipartFormInputTempFile(boundary: boundary)
		multipart.addPart(named: "file", fileURL: dummyFile, contentType: "application/octet-stream")

		let multipartFile = try await multipart.renderToFile()
		defer { try? FileManager.default.removeItem(at: multipartFile) }

		let multipartHash = try fileHash(multipartFile)

		let awsHeaderInfo = try AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: "\(multipartHash.toHexString())")
		request = try awsHeaderInfo.processRequest(request)

		request.payload = .upload(.localFile(multipartFile))

		addTeardownBlock {
			try? FileManager.default.removeItem(at: dummyFile)
		}

		_ = try await networkHandler.transferMahDatas(for: request)

		let dlRequest = url.request

		let downloadedResult = try await networkHandler.transferMahDatas(for: dlRequest)
		XCTAssertEqual(SHA256.hash(data: downloadedResult.data), multipartHash)
		try checkNetworkHandlerTasksFinished(networkHandler)
	}

	func testUploadMultipartStream() async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			XCTFail("Need s3 credentials")
			return
		}

		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 10

		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		defer { try? FileManager.default.removeItem(at: dummyFile) }
		try generateRandomBytes(in: dummyFile, megabytes: sizeOfUploadMB)

		let boundary = "asdlfkjasdf"
		let multipart = MultipartFormInputStream(boundary: boundary)
		try multipart.addPart(named: "file", fileURL: dummyFile, contentType: "application/octet-stream")

		let multipartHash = try streamHash(multipart.safeCopy())

		let awsHeaderInfo = try AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: "\(multipartHash.toHexString())")
		request = try awsHeaderInfo.processRequest(request)

		request.payload = .upload(.inputStream(multipart))

		addTeardownBlock {
			try? FileManager.default.removeItem(at: dummyFile)
		}

		_ = try await networkHandler.transferMahDatas(for: request)

		let dlRequest = url.request

		let downloadedResult = try await networkHandler.transferMahDatas(for: dlRequest)
		XCTAssertEqual(SHA256.hash(data: downloadedResult.data), multipartHash)
		try checkNetworkHandlerTasksFinished(networkHandler)
	}

	/// Tests using a mock session that corrupt data is properly reported as NetworkError.dataCodingError
	func testBadData() async throws {

		let networkHandler = generateNetworkHandlerInstance()
		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		let mockData = try JSONEncoder().encode(demoModel)[0...20]

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 200)

		let task = Task { () -> DemoModel in
			try await networkHandler.transferMahCodableDatas(for: dummyModelURL.request).decoded
		}
		let theResult = await task.result

		XCTAssertThrowsError(try theResult.get(), "No error when error expected") { error in
			guard case NetworkError.dataCodingError = error else {
				XCTFail("Error other than data coding error: \(error)")
				return
			}
		}
	}

	func testCancellingSessionTask() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let sampleURL = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
		await NetworkHandlerMocker.addMock(for: sampleURL, method: .get, smartBlock: { _, _, _ in
			(Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024 * 10), 200)
		})

		let delegate = TestingDelegate()
		var sessionTask: URLSessionTask?
		delegate
			.taskPub
			.sink {
				sessionTask = $0
			}

		delegate
			.progressPub
			// must not cancel a task on the same queue it receives updates from
			.receive(on: .global(qos: .userInteractive))
			.sink {
				guard $0 > 0.25, sessionTask?.state != .canceling else { return }
				sessionTask?.cancel()
			}

		let task = Task {
			try await networkHandler.transferMahDatas(for: sampleURL.request, delegate: delegate).data
		}
		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Expected cancelled error") { error in
			guard case NetworkError.requestCancelled = error else {
				XCTFail("incorrect error: \(error)")
				return
			}
		}
	}

	func testCancellingDownload() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let sampleURL = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
		await NetworkHandlerMocker.addMock(for: sampleURL, method: .get, smartBlock: { _, _, _ in
			(Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024 * 10), 200)
		})

		let delegate = TestingDelegate()

		let task = Task {
			try await networkHandler.transferMahDatas(for: sampleURL.request, delegate: delegate).data
		}
		var completed = false
		delegate
			.progressPub
			// must not cancel a task on the same queue it receives updates from
			.receive(on: .global(qos: .userInteractive))
			.sink {
				guard $0 > 0.25, completed == false else { return }
				XCTAssertEqual(1, networkHandler.taskHolders.count)
				task.cancel()
				completed = true
			}

		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Expected cancelled error") { error in
			guard case NetworkError.requestCancelled = error else {
				XCTFail("incorrect error: \(error)")
				return
			}
		}
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	func testCancellingUpload() async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			XCTFail("Need s3 credentials")
			return
		}

		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 5

		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		try generateRandomBytes(in: dummyFile, megabytes: sizeOfUploadMB)

		let dataHash = try fileHash(dummyFile)

		let awsHeaderInfo = try AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(dataHash))
		request = try awsHeaderInfo.processRequest(request)

		request.payload = .upload(.localFile(dummyFile))

		addTeardownBlock {
			try? FileManager.default.removeItem(at: dummyFile)
		}

		let delegate = TestingDelegate()

		let task = Task {
			try await networkHandler.transferMahDatas(for: url.request, delegate: delegate).data
		}
		var completed = false
		delegate
			.progressPub
			// must not cancel a task on the same queue it receives updates from
			.receive(on: .global(qos: .userInteractive))
			.sink {
				guard $0 > 0.25, completed == false else { return }
				task.cancel()
				completed = true
			}

		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Expected cancelled error") { error in
			guard case NetworkError.requestCancelled = error else {
				XCTFail("incorrect error: \(error)")
				return
			}
		}

		try checkNetworkHandlerTasksFinished(networkHandler)
		XCTAssertTrue(networkHandler.taskHolders.isEmpty)
	}

	func testImmediateCancellingSessionTask() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let sampleURL = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
		await NetworkHandlerMocker.addMock(for: sampleURL, method: .get, smartBlock: { _, _, _ in
			(Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024 * 10), 200)
		})

		let delegate = TestingDelegate()
		delegate
			.taskPub
		// must not cancel a task on the same queue it receives updates from
			.receive(on: DispatchQueue(label: "consistent queue"))
			.sink {
				$0.cancel()
			}

		let task = Task {
			try await networkHandler.transferMahDatas(for: sampleURL.request, delegate: delegate).data
		}
		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Expected cancelled error") { error in
			guard case NetworkError.requestCancelled = error else {
				XCTFail("incorrect error: \(error)")
				return
			}
		}
	}

	func testCancellingAsyncTask() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let sampleURL = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
		await NetworkHandlerMocker.addMock(for: sampleURL, method: .get, smartBlock: { _, _, _ in
			(Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024 * 10), 200)
		})

		let delegate = TestingDelegate()

		let task = Task {
			try await networkHandler.transferMahDatas(for: sampleURL.request, delegate: delegate).data
		}

		delegate
			.progressPub
			.sink {
				guard $0 > 0.25, task.isCancelled == false else { return }
				task.cancel()
			}

		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Expected cancelled error") { error in
			guard case NetworkError.requestCancelled = error else {
				XCTFail("incorrect error: \(error)")
				return
			}
		}
	}

	func testImmediateCancellingAsyncTask() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let sampleURL = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
		await NetworkHandlerMocker.addMock(for: sampleURL, method: .get, smartBlock: { _, _, _ in
			(Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024 * 10), 200)
		})

		let delegate = TestingDelegate()

		let task = Task {
			try await networkHandler.transferMahDatas(for: sampleURL.request, delegate: delegate).data
		}
		task.cancel()

		let result = await task.result

		XCTAssertThrowsError(try result.get(), "Expected cancelled error") { error in
			guard case NetworkError.requestCancelled = error else {
				XCTFail("incorrect error: \(error)")
				return
			}
		}
	}

	/// Confirms that cancelling a poll (aka download) task causes immediate cancellation and doesn't end up waiting for a timeout
	func testDelayedResponseCancel() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: true)

		let sampleURL = #URL("https://yummy.pizza/longPoll")
		let resultData = (Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024), 200)
		await NetworkHandlerMocker.addMock(
			for: sampleURL,
			method: .get,
			smartBlock: { _, _, _ in
				try await Task.sleep(nanoseconds: 5_000_000_000)
				return resultData
			})

		var request = sampleURL.request
		request.timeoutInterval = 10

		let pollCount = AtomicValue(value: 0)

		let task = Task { [request] in
			let finalResult: (Data, HTTPURLResponse) = try await networkHandler.poll(
				request: request,
				until: { previousRequest, previousResult in
					defer { pollCount.value += 1 }
					guard pollCount.value < 3 else { return .finish(previousResult) }

					print(pollCount)

					return .continue(previousRequest, 0.5)
				})
			return finalResult
		}
		try await Task.sleep(for: .seconds(0.5))
		let start = Date()
		task.cancel()
		let result = await task.result
		let end = Date()

		XCTAssertThrowsError(try result.get())
		let transpiredTime = end.timeIntervalSince(start)
		XCTAssertLessThan(transpiredTime, 1.5)
	}

	/// Tests that timeouts will trigger retry attempts. Will fail if timeout isn't triggered, so if you have an uber
	/// fast connection, it might falsely fail.
	func testTimeoutTriggersRetry() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = #URL("https://s3.wasabisys.com/network-handler-tests/uploader.bin")
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		addTeardownBlock {
			try await Task.sleep(nanoseconds: 1_000_000_000)
		}

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 5

		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		try generateRandomBytes(in: dummyFile, megabytes: sizeOfUploadMB)

		let dataHash = try fileHash(dummyFile)

		let awsHeaderInfo = try AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: "\(dataHash.toHexString())")
		request = try awsHeaderInfo.processRequest(request)

		request.payload = .upload(.localFile(dummyFile))
		request.timeoutInterval = 0.0001

		let delegate = TestingDelegate()
		delegate
			.progressPub
			// must not cancel a task on the same queue it receives updates from
			.receive(on: .global(qos: .userInteractive))
			.sink {
				print("prog: \($0)")
			}

		let atomicFailCount = AtomicValue(value: 0)
		let expectedFailCount = 3

		let throwingTask = Task { [request] in
			try await networkHandler.transferMahDatas(
				for: request,
				delegate: delegate) { _, failCount, error in
					XCTAssertFalse(error.isCancellation())
					atomicFailCount.value = failCount
					guard failCount < expectedFailCount else { return .throw }
					print("❤️ retrying: \(request.url!)")
					return .retry
				}
		}

		let result = await throwingTask.result

		XCTAssertThrowsError(try result.get())
		XCTAssertEqual(atomicFailCount.value, expectedFailCount)
	}
}
