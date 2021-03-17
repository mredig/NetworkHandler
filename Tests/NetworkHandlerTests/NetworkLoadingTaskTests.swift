//swiftlint:disable

import XCTest
@testable import NetworkHandler

/// Obviously dependent on network conditions
class NetworkLoadingTaskTests: NetworkHandlerBaseTest {

	/// tests progress tracking when downloading
	func testDownloadProgress() {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		let waitForMocking = expectation(description: "Wait for mocking")
		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
			waitForMocking.fulfill()
		}

		var progressTracker: [Double] = []
		handle.onProgressUpdated { task in
			progressTracker.append(task.progress.fractionCompleted)
		}

		wait(for: [waitForMocking], timeout: 30)

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
	func testUploadProgress() {
		let networkHandler = generateNetworkHandlerInstance()

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
		let randomValues: [UInt8] = (0..<(1024 * 1024 * sizeOfUploadMB)).map { _ in UInt8.random(in: 0...UInt8.max) }

		let string = "\(method.rawValue)\n\n\n\(formatter.string(from: now))\n\(url.path)"
		let signature = string.hmac(algorithm: .sha1, key: TestEnvironment.s3AccessSecret)


		request.addValue("\(formatter.string(from: now))", forHTTPHeaderField: .date)
		request.addValue("AWS \(TestEnvironment.s3AccessKey):\(signature)", forHTTPHeaderField: .authorization)
		request.httpBody = Data(randomValues)

		let waitForMocking = expectation(description: "Wait for mocking")
		let handle = networkHandler.transferMahDatas(with: request) { result in
			defer { waitForMocking.fulfill() }
			if case .failure(let error) = result {
				XCTFail("Upload failed: \(error)")
			}
		}


		var progressTracker: [Double] = []
		handle.onProgressUpdated { task in
			progressTracker.append(task.progress.fractionCompleted)
		}

		wait(for: [waitForMocking], timeout: 30)

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

	func testOnTaskCompletion() {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		let waitForMocking = expectation(description: "Wait for mocking")
		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
			waitForMocking.fulfill()
		}

		let waitForCompletion = expectation(description: "wait for completion handler")
		handle.onCompletion { task in
			waitForCompletion.fulfill()
		}

		wait(for: [waitForMocking, waitForCompletion], timeout: 10)

		let runCompletedAfterwards = expectation(description: "run again")
		handle.onCompletion { task in
			runCompletedAfterwards.fulfill()
		}

		wait(for: [runCompletedAfterwards], timeout: 10)
	}

	func testDataAfterCompletion() {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		let waitForMocking = expectation(description: "Wait for mocking")
		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
			waitForMocking.fulfill()
		}
		XCTAssertNil(handle.result)

		let waitForCompletion = expectation(description: "wait for completion handler")
		handle.onCompletion { task in
			XCTAssertNotNil(task.result)
			waitForCompletion.fulfill()
		}

		wait(for: [waitForMocking, waitForCompletion], timeout: 10)

		XCTAssertNotNil(handle.result)
	}
}
