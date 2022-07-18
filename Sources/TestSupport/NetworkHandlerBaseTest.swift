@testable import NetworkHandler
import XCTest

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
