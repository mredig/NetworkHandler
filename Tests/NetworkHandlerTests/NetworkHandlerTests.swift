//swiftlint:disable

import XCTest
@testable import NetworkHandler
import CryptoSwift
import TestSupport

#if os(macOS)
typealias TestImage = NSImage
#elseif os(iOS)
typealias TestImage = UIImage
#else
#endif

/// Obviously dependent on network conditions
class NetworkHandlerTests: NetworkHandlerBaseTest {

	// MARK: - Properties
	var demoModelController: DemoModelController?
	let imageURL = URL(string: "https://placekitten.com/300/300")!

	// MARK: - Lifecycle
	override func setUp() {
		super.setUp()
		demoModelController = DemoModelController()
	}

	override func tearDown() {
		super.tearDown()

		let networkHandler = generateNetworkHandlerInstance()
		networkHandler.cache.reset()
	}

	// MARK: - Live Network Tests
	/// Tests downloading over a live connection, caching the download, and subsequently loading the file from cache.
	func testImageDownloadAndCache() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		// completely disabling cache and creating a new url session with each request isn't strictly or even typically
		// necessary. This is done just to absolutely confirm the test is working.
		let loader = { () -> URLSession in
			let config = URLSessionConfiguration.ephemeral
			config.urlCache = nil
			config.requestCachePolicy = .reloadIgnoringCacheData
			return URLSession(configuration: config)
		}

		let networkStart = CFAbsoluteTimeGetCurrent()
		let image1Result = try await networkHandler.transferMyDatas(for: imageURL.request, usingCache: .key("kitten"), session: loader())
		let networkFinish = CFAbsoluteTimeGetCurrent()


		// now try retrieving from cache
		let cacheStart = CFAbsoluteTimeGetCurrent()
		let image2Result = try await networkHandler.transferMyDatas(for: imageURL.request, usingCache: .key("kitten"), session: loader())
		let cacheFinish = CFAbsoluteTimeGetCurrent()


		// calculate cache speed improvement, just for funsies
		let networkDuration = networkFinish - networkStart
		let cacheDuration = cacheFinish - cacheStart
		let cacheRatio = cacheDuration / networkDuration
		print("netDuration: \(networkDuration)\ncacheDuration: \(cacheDuration)\ncache took \(cacheRatio)x as long")
		XCTAssertLessThan(cacheDuration,
						  networkDuration * 0.5,
						  "The cache lookup wasn't even twice as fast as the original lookup. It's possible the cache isn't working")

		let imageOneData = image1Result.data
		let imageTwoData = image2Result.data
		XCTAssertEqual(imageOneData, imageTwoData, "hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)")

		XCTAssertNotNil(TestImage(data: imageOneData))
	}

	// MARK: - Mock Network Tests
	/// Tests using a Mock Session that is successful.
	func testMockDataSuccess() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		// expected result
		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)

		let mockData = try JSONEncoder().encode(demoModel)

		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
		let dummyModelURL = dummyBaseURL
			.appendingPathComponent(demoModel.id.uuidString)
			.appendingPathExtension("json")

		await NetworkHandlerMocker.addMock(for: dummyModelURL, method: .get, data: mockData, code: 200)

		let result: DemoModel = try await networkHandler.transferMahCodableDatas(for: dummyModelURL.request).decoded
		XCTAssertEqual(demoModel, result)
	}

	/// Tests using a Mock session that checks a multitude of errors, also confirming that normal errors are wrapped in a NetworkError properly
//	func testMockDataErrors() {
//
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
//			networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, Error>) in
//				theResult = result
//				waitForMocking.fulfill()
//			}
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
//				// though, so the followup case is to confirm that it was properly wrapped after going through NetworkHandler's transfer
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
//	func testMock404Response() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		let mockSession = NetworkMockingSession(mockData: nil, mockError: nil, mockResponseCode: 404)
//
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//
//		wait(for: [waitForMocking], timeout: 10)
//		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
//			let expectedError = NetworkError.httpNon200StatusCode(code: 404, data: nil)
//			XCTAssertEqual(expectedError, error as? NetworkError)
//		}
//	}

	/// Tests using a mock session that when expecting ONLY a 200 response code, a 200 code will be an expected success
//	func testRespect200OnlyAndGet200() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockData = {
//			try? JSONEncoder().encode(demoModel)
//		}()
//		let mockSession200 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 200)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		var request = dummyModelURL.request
//		request.expectedResponseCodes = 200
//
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: request, session: mockSession200) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//		wait(for: [waitForMocking], timeout: 10)
//
//		XCTAssertNoThrow(try theResult?.get())
//		XCTAssertEqual(try theResult?.get(), demoModel)
//	}

	/// Tests using a Mock session that when expecting ONLY a 200 response code, even a 202 code will cause an error to be thrown
//	func testRespect200OnlyButGet202() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockData = {
//			try? JSONEncoder().encode(demoModel)
//		}()
//		let mockSession202 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 202)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		var request = dummyModelURL.request
//		request.expectedResponseCodes = 200
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: request, session: mockSession202) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//
//		wait(for: [waitForMocking], timeout: 10)
//
//		XCTAssertThrowsError(try theResult?.get(), "Got unexpected error") { error in
//			XCTAssertEqual(NetworkError.httpNon200StatusCode(code: 202, data: mockData), error as? NetworkError)
//		}
//	}

//	func testUploadFile() throws {
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
//		var request = url.request
//		let method = HTTPMethod.put
//		request.httpMethod = method
//
//		let formatter = DateFormatter()
//		formatter.locale = Locale(identifier: "en_US_POSIX")
//		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
//
//		let now = Date()
//
//		// this can be changed per run depending on internet variables - large enough to take more than an instant,
//		// small enough to not timeout.
//		let sizeOfUploadMB = 10
//
//		let dummyFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
//		let outputStream = OutputStream(url: dummyFile, append: false)
//		outputStream?.open()
//		let length = 1024 * 1024
//		let gibberish = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
//		let raw = UnsafeMutableRawPointer(gibberish)
//		let quicker = raw.bindMemory(to: UInt64.self, capacity: length / 8)
//		var hasher = MD5()
//
//		try (0..<sizeOfUploadMB).forEach { _ in
//			for i in 0..<(length / 8) {
//				quicker[i] = UInt64.random(in: 0...UInt64.max)
//			}
//
//			_ = try hasher.update(withBytes: Array(Data(bytes: gibberish, count: length)))
//			outputStream?.write(gibberish, maxLength: length)
//		}
//		outputStream?.close()
//		gibberish.deallocate()
//
//		let inputStream = InputStream(url: dummyFile)
//
//		let dataHash = try hasher.finish()
//
//		let string = "\(method.rawValue)\n\n\n\(formatter.string(from: now))\n\(url.path)"
//		let signature = string.hmac(algorithm: .sha1, key: TestEnvironment.s3AccessSecret)
//
//
//		request.addValue("\(formatter.string(from: now))", forHTTPHeaderField: .date)
//		request.addValue("AWS \(TestEnvironment.s3AccessKey):\(signature)", forHTTPHeaderField: .authorization)
//		request.httpBodyStream = inputStream
//		addTeardownBlock {
//			try? FileManager.default.removeItem(at: dummyFile)
//		}
//
//		let waitForUpload = expectation(description: "Wait for upload")
//		var theResult: Result<Data?, Error>?
//		let handle = networkHandler.transferMahOptionalDatas(with: request, completion: { result in
//			theResult = result
//			waitForUpload.fulfill()
//		})
//
//		wait(for: [waitForUpload], timeout: 30)
//
//		XCTAssertNoThrow(try theResult?.get())
//		XCTAssertEqual(handle.status, .completed)
//
//		let waitForDownload = expectation(description: "Wait for download")
//		let dlRequest = url.request
//		let dlHandle = networkHandler.transferMahDatas(with: dlRequest, completion: { result in
//			do {
//				XCTAssertNoThrow(try result.get())
//				let uploadedData = try result.get()
//				XCTAssertEqual(uploadedData.md5().toHexString(), dataHash.toHexString())
//			} catch {
//				print("Error confirming upload: \(error)")
//			}
//			waitForDownload.fulfill()
//		})
//
//		wait(for: [waitForDownload], timeout: 30)
//		XCTAssertEqual(dlHandle.status, .completed)
//	}

	/// Tests using a mock session that expected response ranges are respsected
//	func testRespectResponseRangeGetValidResponse() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockData = {
//			try? JSONEncoder().encode(demoModel)
//		}()
//		let mockSession200 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 200)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		var request = dummyModelURL.request
//		request.expectedResponseCodes.insertRange(200...299)
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: request, session: mockSession200) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//		wait(for: [waitForMocking], timeout: 10)
//
//		XCTAssertNoThrow(try theResult?.get())
//		XCTAssertEqual(demoModel, try theResult?.get())
//	}

	/// Tests using a mock session that values outside the expected response ranges are thrown
//	func testRespectResponseRangeGetInvalidResponse() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockData = {
//			try? JSONEncoder().encode(demoModel)
//		}()
//		let mockSession202 = NetworkMockingSession(mockData: mockData, mockError: nil, mockResponseCode: 202)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		var request = dummyModelURL.request
//		request.expectedResponseCodes.insertRange(200...201)
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: request, session: mockSession202) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//
//		wait(for: [waitForMocking], timeout: 10)
//		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
//			let expectedError = NetworkError.httpNon200StatusCode(code: 202, data: mockData)
//			XCTAssertEqual(expectedError, error as? NetworkError)
//		}
//	}

	/// Tests using a mock session that responses containing "null" are properly reflected by the NetworkError.dataWasNull (might be specific to firebase)
//	func testNullData() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockSession = NetworkMockingSession(mockData: "null".data(using: .utf8), mockError: nil)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//
//		wait(for: [waitForMocking], timeout: 10)
//
//		XCTAssertThrowsError(try theResult?.get(), "No error when an error expected") { error in
//			XCTAssertEqual(NetworkError.dataWasNull, error as? NetworkError)
//		}
//	}

	/// Tests using a mock session that corrupt data is properly reported as NetworkError.dataCodingError
//	func testBadData() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockData = {
//			try? JSONEncoder().encode(demoModel)[0...20]
//		}()
//		let mockSession = NetworkMockingSession(mockData: mockData, mockError: nil)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//
//		wait(for: [waitForMocking], timeout: 10)
//		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
//			guard case NetworkError.dataCodingError = error else {
//				XCTFail("Error other than data coding error: \(error)")
//				return
//			}
//		}
//	}

	/// Tests using a mock session that nil data is reported as NetworkError.badData
//	func testNoData() {
//
//		let networkHandler = generateNetworkHandlerInstance()
//		// expected result
//		let demoModel = DemoModel(title: "Test model", subtitle: "test Sub", imageURL: imageURL)
//
//		// mock data doesn't need a valid data source passed in, but it's wise to make it the same as your actual source
//		let dummyBaseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
//		let dummyModelURL = dummyBaseURL
//			.appendingPathComponent(demoModel.id.uuidString)
//			.appendingPathExtension("json")
//
//		let mockSession = NetworkMockingSession(mockData: nil, mockError: nil)
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		var theResult: Result<DemoModel, Error>?
//		networkHandler.transferMahCodableDatas(with: dummyModelURL.request, session: mockSession) { (result: Result<DemoModel, Error>) in
//			theResult = result
//			waitForMocking.fulfill()
//		}
//
//		wait(for: [waitForMocking], timeout: 10)
//		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
//			XCTAssertEqual(NetworkError.badData(sourceData: nil), error as? NetworkError)
//		}
//	}

//	func testUpstreamErrorOccured() {
//		let errorValue = "Arbitrary upstream error!"
//		let mock = NetworkMockingSession(mockData: nil, mockError: errorValue, mockResponseCode: nil)
//
//		let networkHandler = generateNetworkHandlerInstance()
//		let dummyURL = URL(string: "https://networkhandlertestbase.firebaseio.com/")!
//
//		let waitForMock = expectation(description: "Wait for mocking")
//		var theResult: Result<Data?, Error>?
//		networkHandler.transferMahOptionalDatas(with: dummyURL.request, session: mock) { result in
//			theResult = result
//			waitForMock.fulfill()
//		}
//
//		wait(for: [waitForMock], timeout: 10)
//		XCTAssertThrowsError(try theResult?.get(), "No error when error expected") { error in
//			XCTAssertEqual(NetworkError.otherError(error: errorValue), error as? NetworkError)
//		}
//	}
}

extension String: Error {}
