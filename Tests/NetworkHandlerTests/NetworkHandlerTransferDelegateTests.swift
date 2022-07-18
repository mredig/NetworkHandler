//swiftlint:disable

import XCTest
@testable import NetworkHandler
import TestSupport

class DownloadDelegate: NetworkHandlerTransferDelegate {
	let taskPub = NHPublisher<URLSessionTask, Never>()
	let progressPub = NHPublisher<Double, Never>()
	let statePub = NHPublisher<URLSessionTask.State, Never>()

	func networkHandlerTaskDidStart(_ task: URLSessionTask) {
		taskPub.send(task)
	}

	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double) {
		progressPub.send(progress)
	}

	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State) {
		statePub.send(state)
	}
}

/// Obviously dependent on network conditions
class NetworkHandlerTransferDelegateTests: NetworkHandlerBaseTest {

	/// tests progress tracking when downloading
	func testDownloadProgress() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		var progressTracker: [Double] = []

		let myDel = DownloadDelegate()
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

		let sessionID = UUID()
		let sessionConfig = URLSessionConfiguration.background(withIdentifier: sessionID.uuidString)
		sessionConfig.shouldUseExtendedBackgroundIdleMode = true
		sessionConfig.isDiscretionary = false
		let networkHandler = NetworkHandler(name: "Test Network Handler", configuration: sessionConfig)

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

		let myDel = DownloadDelegate()
		myDel.progressPub.sink {
			progressTracker.append($0)
		}

		try await networkHandler.transferMahDatas(for: request, delegate: myDel)

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
	}

	func testOnTaskStatusChange() async throws {
		let networkHandler = generateNetworkHandlerInstance(mockedDefaultSession: false)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		let expectedStatuses: [URLSessionTask.State] = [.suspended, .running, .completed]

		var statuses: [URLSessionTask.State] = []

		let myDel = DownloadDelegate()
		myDel.statePub
			.receive(on: .main)
			.removeDuplicates()
			.sink {
				statuses.append($0)
			}

		try await networkHandler.transferMahDatas(for: url.request, delegate: myDel)

		try await wait(forArbitraryCondition: statuses.count == 3)

		XCTAssertEqual(expectedStatuses, statuses)
	}
}
