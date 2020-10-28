//swiftlint:disable

import XCTest
@testable import NetworkHandler

/// Obviously dependent on network conditions
class NetworkLoadingTaskTests: XCTestCase {

	/// tests progress tracking when downloading
	func testDownloadProgress() {
		let networkHandler = NetworkHandler()

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/randomData.bin")!

		let waitForMocking = expectation(description: "Wait for mocking")
		let handle = networkHandler.transferMahDatas(with: url.request) { _ in
			waitForMocking.fulfill()
		}

		var progress: Int64 = 0
		handle.onDownloadProgressUpdated { task in
			XCTAssertGreaterThanOrEqual(task.countOfBytesSent, progress)
			progress = task.countOfBytesSent
		}

		wait(for: [waitForMocking], timeout: 10)
	}

	/// tests progress tracking when uploading - will fail without api/secret for wasabi in environment
	func testUploadProgress() {
		let networkHandler = NetworkHandler()

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!
		var request = url.request
		let method = HTTPMethod.put
		request.httpMethod = method

		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

		let now = Date()

		let randomValues: [UInt8] = (0..<(1024*1024)).map { _ in UInt8.random(in: 0...UInt8.max) }

		let string = "\(method.rawValue)\n\n\n\(formatter.string(from: now))\n\(url.path)"
		let signature = string.hmac(algorithm: .sha1, key: TestEnvironment.s3AccessSecret)


		request.addValue(.other(value: formatter.string(from: now)), forHTTPHeaderField: .commonKey(key: .date))
		request.addValue(.other(value: "AWS \(TestEnvironment.s3AccessKey):\(signature)"), forHTTPHeaderField: .commonKey(key: .authorization))
		request.httpBody = Data(randomValues)

		let waitForMocking = expectation(description: "Wait for mocking")
		let handle = networkHandler.transferMahDatas(with: request) { _ in
			waitForMocking.fulfill()
		}

		var progress: Int64 = 0
		handle.onUploadProgressUpdated { task in
			XCTAssertGreaterThanOrEqual(task.countOfBytesSent, progress)
			progress = task.countOfBytesSent
		}

		wait(for: [waitForMocking], timeout: 10)
	}

	func testOnTaskCompletion() {
		let networkHandler = NetworkHandler()

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
		let networkHandler = NetworkHandler()

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
