@testable import NetworkHandler
import NetworkHandlerMockingEngine
import XCTest
import Crypto
import Foundation

#if os(macOS)
public typealias TestImage = NSImage
#elseif os(iOS)
public typealias TestImage = UIImage
#else
#endif

open class NetworkHandlerBaseTest<Engine: NetworkEngine>: XCTestCase {
	public func generateNetworkHandlerInstance(engine: Engine) -> NetworkHandler<Engine> {
		let networkHandler = NetworkHandler(name: "Test Network Handler", engine: engine)
		addTeardownBlock {
			networkHandler.resetCache()
		}
		networkHandler.resetCache()
		return networkHandler
	}

	public func wait(
		forArbitraryCondition arbitraryCondition: @autoclosure () async throws -> Bool,
		timeout: TimeInterval = 10
	) async throws {
		let start = Date()
		while try await arbitraryCondition() == false {
			let elapsed = Date().timeIntervalSince(start)
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
			for index in 0..<(length / 8) {
				quicker[index] = UInt64.random(in: 0...UInt64.max)
			}

			outputStream?.write(buffer, maxLength: length)
		}
		outputStream?.close()
		buffer.deallocate()
	}

	public func fileHash(_ url: URL) throws -> SHA256Digest {
		guard let input = InputStream(url: url) else { throw NSError(domain: "Error loading file for hashing", code: -1) }

		return try streamHash(input)
	}

	public func streamHash(_ input: InputStream) throws -> SHA256Digest {
		var hasher = SHA256()

		let bufferSize = 1024 // KB
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
}

extension Mirror {
	func firstChild<T>(named name: String) -> T? {
		children.first(where: {
			guard $0.value is T else { return false }

			return $0.label == name ? true : false
		})?.value as? T
	}
}
