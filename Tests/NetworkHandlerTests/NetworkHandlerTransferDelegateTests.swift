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
				print($0)
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
			print($0)
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
//
//	func testOnTaskCompletion() {
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
//			waitForMocking.fulfill()
//		}
//
//		let waitForCompletion = expectation(description: "wait for completion handler")
//		handle.onCompletion { task in
//			waitForCompletion.fulfill()
//		}
//
//		wait(for: [waitForMocking, waitForCompletion], timeout: 10)
//
//		let runCompletedAfterwards = expectation(description: "run again")
//		handle.onCompletion { task in
//			runCompletedAfterwards.fulfill()
//		}
//
//		wait(for: [runCompletedAfterwards], timeout: 10)
//	}
//
//	func testOnTaskStatusChange() {
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
//
//		var delayRequest = url.request
//		delayRequest.automaticStart = false
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
//			waitForMocking.fulfill()
//		}
//
//		let expectedStatuses: [NetworkLoadingTaskStatus] = [.running, .running, .completed]
//
//		let serialQueue = DispatchQueue(label: "statuses queue")
//		var statuses: [NetworkLoadingTaskStatus] = []
//
//		handle.onStatusUpdated { task in
//			serialQueue.sync {
//				statuses.append(task.status)
//			}
//		}
//
//		let waitForCompletion = expectation(description: "wait for completion handler")
//		handle.onCompletion { task in
//			waitForCompletion.fulfill()
//		}
//
//		handle.resume()
//
//		wait(for: [waitForMocking, waitForCompletion], timeout: 10)
//
//		let runCompletedAfterwards = expectation(description: "run again")
//		handle.onCompletion { task in
//			runCompletedAfterwards.fulfill()
//		}
//
//		wait(for: [runCompletedAfterwards], timeout: 10)
//
//		XCTAssertEqual(expectedStatuses, statuses)
//	}
//
//	func testDataAfterCompletion() {
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
//
//		let waitForMocking = expectation(description: "Wait for mocking")
//		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
//			waitForMocking.fulfill()
//		}
//		XCTAssertNil(handle.result)
//
//		let waitForCompletion = expectation(description: "wait for completion handler")
//		handle.onCompletion { task in
//			XCTAssertNotNil(task.result)
//			waitForCompletion.fulfill()
//		}
//
//		wait(for: [waitForMocking, waitForCompletion], timeout: 10)
//
//		XCTAssertNotNil(handle.result)
//	}
}

//#if canImport(Combine)
//import Combine
//
//@available(iOS 13.0, tvOS 13.0, macOS 15.0, watchOS 6.0, *)
//extension NetworkLoadingTaskTests {
//
//	func testCombine() {
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!
//
//		var delayRequest = url.request
//		delayRequest.automaticStart = false
//
//		let waitForCompletion = expectation(description: "Wait for mocking")
//		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
//			waitForCompletion.fulfill()
//		}
//
//		var bag: Set<AnyCancellable> = []
//
//		var completionPublishCount = 0
//		var statusOnePublishCount = 0
//		var statusTwoPublishCount = 0
//		var progressPublishCount = 0
//
//		handle
//			.completionPublisher
//			.sink(receiveValue: { _ in completionPublishCount += 1 })
//			.store(in: &bag)
//
//		handle
//			.progressPublisher
//			.sink(receiveValue: { _ in progressPublishCount += 1 })
//			.store(in: &bag)
//
//		handle
//			.statusPublisher
//			.sink(receiveValue: { _ in statusOnePublishCount += 1 })
//			.store(in: &bag)
//
//		handle
//			.statusPublisher
//			.sink(receiveValue: { _ in statusTwoPublishCount += 1 })
//			.store(in: &bag)
//
//		handle.resume()
//
//		wait(for: [waitForCompletion], timeout: 10)
//
//		let runCompletedAfterwards = expectation(description: "run again")
//		runCompletedAfterwards.expectedFulfillmentCount = 3
//		handle.onCompletion { task in
//			runCompletedAfterwards.fulfill()
//		}
//		handle.onCompletion { task in
//			runCompletedAfterwards.fulfill()
//		}
//		handle.onCompletion { task in
//			runCompletedAfterwards.fulfill()
//		}
//
//		wait(for: [runCompletedAfterwards], timeout: 10)
//
//		XCTAssertEqual(statusOnePublishCount, statusTwoPublishCount)
//		XCTAssertGreaterThan(statusOnePublishCount, 0)
//		XCTAssertEqual(completionPublishCount, 1)
//		XCTAssertGreaterThan(progressPublishCount, 0)
//	}
//}
//#endif
