import NetworkHandler
import XCTest

open class NetworkHandlerBaseTest: XCTestCase {

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

	public struct TestError: Error {
		let message: String
	}
}
