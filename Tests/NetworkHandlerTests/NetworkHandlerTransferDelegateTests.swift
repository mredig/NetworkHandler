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
		let sizeOfUploadMB = 10

		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let outputStream = OutputStream(url: tempFile, append: false)
		outputStream?.open()
		let length = 1024 * sizeOfUploadMB
		let gibberish = UnsafeMutablePointer<UInt8>.allocate(capacity: length)

		(0..<1024).forEach { _ in
			(0..<length).forEach {
				gibberish[$0] = UInt8.random(in: 0...UInt8.max)
			}

			outputStream?.write(gibberish, maxLength: length)
		}
		outputStream?.close()
		gibberish.deallocate()

		let inputStream = InputStream(url: tempFile)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: tempFile)
		}

		let string = "\(method.rawValue)\n\n\n\(formatter.string(from: now))\n\(url.path)"
		let signature = string.hmac(algorithm: .sha1, key: TestEnvironment.s3AccessSecret)


		request.addValue("\(formatter.string(from: now))", forHTTPHeaderField: .date)
		request.addValue("AWS \(TestEnvironment.s3AccessKey):\(signature)", forHTTPHeaderField: .authorization)
		request.httpBodyStream = inputStream

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
