import XCTest
@testable import NetworkHandler
import TestSupport
import Swiftwood

/// Obviously dependent on network conditions
class NetworkHandlerTransferDelegateTests: NetworkHandlerBaseTest {

	override func setUp() {
		super.setUp()

		let consoleDest = ConsoleLogDestination(maxBytesDisplayed: -1)
		consoleDest.minimumLogLevel = .veryVerbose
		log.appendDestination(consoleDest, replicationOption: .forfeitToAlike)
	}

	/// tests progress tracking when downloading
	func testDownloadProgress() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		var progressTracker: [Double] = []

		let myDel = TestingDelegate()
		myDel.progressPub
			.sink {
				progressTracker.append($0)
			}

		try await networkHandler.transferMahDatas(for: url.request, delegate: myDel)

		XCTAssertGreaterThan(progressTracker.count, 2)

		let progressDeltaTracker = progressTracker
			.reduce(into: [(Double, Double)]() ) {
				let lastValue = $0.last?.0 ?? 0
				$0.append(($1, $1 - lastValue))
			}

		let averageDelta = progressDeltaTracker
			.map(\.1)
			.reduce(0, +) / Double(progressTracker.count)

		XCTAssertGreaterThan(averageDelta, 0)

		log.veryVerbose("\(progressTracker), \(averageDelta)")
	}

	/// tests progress tracking when uploading - will fail without api/secret for wasabi in environment
	func testUploadProgress() async throws {
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

		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

		let now = Date()

		// this can be changed per run depending on internet variables - large enough to take more than an instant,
		// small enough to not timeout.
		let sizeOfUploadMB: UInt8 = 5

		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")

		try generateRandomBytes(in: tempFile, megabytes: sizeOfUploadMB)

		addTeardownBlock {
			try? FileManager.default.removeItem(at: tempFile)
		}

		let awsAuth = try AWSV4Signature(
			for: request,
			date: now,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .unsignedPayload)
		request = try awsAuth.processRequest(request)
		request.payload = .upload(.localFile(tempFile))

		var progressTracker: [Double] = []

		let myDel = TestingDelegate()
		myDel.progressPub.sink {
			progressTracker.append($0)
		}

		// this straight up doesnt work. i dont remember what i was thinking, perhaps hoping that it would work in 5.7? dno
//		#if swift(>=5.7)
//		let sessionID = UUID()
//		let sessionConfig = URLSessionConfiguration.background(withIdentifier: sessionID.uuidString)
//		sessionConfig.shouldUseExtendedBackgroundIdleMode = true
//		sessionConfig.isDiscretionary = false
//		#else
		let sessionConfig: URLSessionConfiguration? = nil
//		#endif

		try await networkHandler.transferMahDatas(for: request, delegate: myDel, sessionConfiguration: sessionConfig)

		XCTAssertGreaterThan(progressTracker.count, 2)

		let progressDeltaTracker = progressTracker
			.reduce(into: [(Double, Double)]() ) {
				let lastValue = $0.last?.0 ?? 0
				$0.append(($1, $1 - lastValue))
			}

		let averageDelta = progressDeltaTracker
			.map(\.1)
			.reduce(0, +) / Double(progressTracker.count)

		XCTAssertGreaterThan(averageDelta, 0)

		log.veryVerbose("\(progressTracker), \(averageDelta)")
		try checkNetworkHandlerTasksFinished(networkHandler)
	}

	func testUploadStatusUpdates() async throws {
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

		let sizeOfUploadMB: UInt8 = 1

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

		var stateAccumulator: Set<URLSessionTask.State> = []

		let dlDelegate = TestingDelegate()
		dlDelegate
			.statePub
			.sink { state in
				stateAccumulator.insert(state)
			}

		let taskStartedExpectation = expectation(description: "task started")
		dlDelegate
			.taskPub
			.sink { _ in
				taskStartedExpectation.fulfill()
			}

		_ = try await networkHandler.transferMahDatas(for: request, delegate: dlDelegate)

		await fulfillment(of: [taskStartedExpectation], timeout: 1)
		XCTAssertEqual(stateAccumulator, [.running, .completed, .suspended])

		try checkNetworkHandlerTasksFinished(networkHandler)
	}

	#if !os(Linux)
	func testDownloadStatusUpdates() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		let expectedStatuses: [URLSessionTask.State] = [.running, .suspended, .running, .completed]

		var statuses: [URLSessionTask.State] = []

		let myDel = TestingDelegate()
		myDel.statePub
			.receive(on: .main)
			.removeDuplicates()
			.sink {
				statuses.append($0)
			}

		let taskStartedExpectation = expectation(description: "task started")
		myDel
			.taskPub
			.sink { _ in
				taskStartedExpectation.fulfill()
			}

		try await networkHandler.transferMahDatas(for: url.request, delegate: myDel)

		await fulfillment(of: [taskStartedExpectation], timeout: 1)

		XCTAssertEqual(expectedStatuses, statuses)
	}
	#endif
}
