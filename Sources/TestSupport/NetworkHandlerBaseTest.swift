@testable import NetworkHandler
import XCTest
import CryptoKit

open class NetworkHandlerBaseTest: XCTestCase {
	open override func tearDown() async throws {
		try await super.tearDown()

		await NetworkHandlerMocker.resetMocks()
	}

	public func generateNetworkHandlerInstance(mockedDefaultSession: Bool = true) -> NetworkHandler {

		let config: URLSessionConfiguration?
		if mockedDefaultSession {
			config = URLSessionConfiguration.default
			config?.protocolClasses = [NetworkHandlerMocker.self]
		} else {
			config = nil
		}
		let networkHandler = NetworkHandler(name: "Test Network Handler", configuration: config)
		return networkHandler
	}

	public func wait(forArbitraryCondition arbitraryCondition: @autoclosure () async throws -> Bool, timeout: TimeInterval = 10) async throws {
		let start = CFAbsoluteTimeGetCurrent()
		while try await arbitraryCondition() == false {
			let elapsed = CFAbsoluteTimeGetCurrent() - start
			if elapsed > timeout {
				throw TestError(message: "Timeout")
			}
			try await Task.sleep(nanoseconds: 1000)
		}
	}

	public struct TestError: Error, LocalizedError {
		let message: String

		public var failureReason: String? { message }
		public var errorDescription: String? { message }
		public var helpAnchor: String? { message }
		public var recoverySuggestion: String? { message }
	}

	public func generateRandomBytes(in file: URL, megabytes: UInt8) throws {
		let outputStream = OutputStream(url: file, append: false)
		outputStream?.open()
		let length = 1024 * 1024
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
		let raw = UnsafeMutableRawPointer(buffer)
		let quicker = raw.bindMemory(to: UInt64.self, capacity: length / 8)

		(0..<megabytes).forEach { _ in
			for i in 0..<(length / 8) {
				quicker[i] = UInt64.random(in: 0...UInt64.max)
			}

			outputStream?.write(buffer, maxLength: length)
		}
		outputStream?.close()
		buffer.deallocate()
	}

	public func fileHash(_ url: URL) throws -> SHA256Digest {
		var hasher = SHA256()

		guard let input = InputStream(url: url) else { throw NSError(domain: "Error loading file for hashing", code: -1) }

		let bufferSize = 1024 //KB
		* 1024 // MB
		* 10 // MB count
		let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferSize)
		guard let pointer = buffer.baseAddress else { throw NSError(domain: "Error allocating buffer", code: -2) }
		input.open()
		while input.hasBytesAvailable {
			let bytesRead = input.read(pointer, maxLength: bufferSize)
			let bufferrr = UnsafeRawBufferPointer(start: pointer, count: bytesRead)
			hasher.update(bufferPointer: bufferrr)
		}
		input.close()

		return hasher.finalize()
	}


	public func checkNetworkHandlerTasksFinished(_ networkHandler: NetworkHandler) throws {
		let nhMirror = Mirror(reflecting: networkHandler)
		let theDel: TheDelegate = nhMirror.firstChild(named: "sessionDelegate")!

		let theDelMirror = Mirror(reflecting: theDel)
		let dataPublishers: [URLSessionTask: TheDelegate.DataPublisher]! = theDelMirror.firstChild(named: "dataPublishers")
		guard dataPublishers.isEmpty else { throw TestError(message: "There are some abandoned tasks in the NH Delegate!") }

		let progressPublishers: [URLSessionTask: TheDelegate.ProgressPublisher]! = theDelMirror.firstChild(named: "progressPublishers")
		guard progressPublishers.isEmpty else { throw TestError(message: "There are some abandoned tasks in the NH Delegate!") }
	}
}

extension Mirror {
	func firstChild<T>(named name: String) -> T? {
		children.first(where: {
			guard let _ = $0.value as? T else { return false }

			return $0.label == name ? true : false
		})?.value as? T
	}
}
