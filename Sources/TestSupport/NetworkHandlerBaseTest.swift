@testable import NetworkHandler
import XCTest

open class NetworkHandlerBaseTest: XCTestCase {

	public func generateNetworkHandlerInstance(mockedDefaultSession: Bool = true) -> NetworkHandler {
		let networkHandler = NetworkHandler(name: "Test Network Handler")

		if mockedDefaultSession {
			let config = URLSessionConfiguration.default
			config.protocolClasses = [NetworkHandlerMocker.self]
			networkHandler.defaultSession = URLSession(configuration: config)
		}
		return networkHandler
	}

}
