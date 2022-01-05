@testable import NetworkHandler
import XCTest

open class NetworkHandlerBaseTest: XCTestCase {

	public func generateNetworkHandlerInstance() -> NetworkHandler {
		.init(name: "Test Network Handler")
	}

}
