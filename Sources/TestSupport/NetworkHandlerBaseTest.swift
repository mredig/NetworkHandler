@testable import NetworkHandler
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

}
