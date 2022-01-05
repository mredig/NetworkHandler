import XCTest
import NetworkHaalpers
import TestSupport

class HTTPMethodTests: XCTestCase {

	func testHTTPMethods() {
		var value: HTTPMethod = .get
		XCTAssertEqual(value.rawValue, "GET")

		value = .delete
		XCTAssertEqual(value.rawValue, "DELETE")

		value = .put
		XCTAssertEqual(value.rawValue, "PUT")

		value = .post
		XCTAssertEqual(value.rawValue, "POST")

		value = .head
		XCTAssertEqual(value.rawValue, "HEAD")

		value = .options
		XCTAssertEqual(value.rawValue, "OPTIONS")

		value = .patch
		XCTAssertEqual(value.rawValue, "PATCH")

		value = "CUSTOM"
		XCTAssertEqual(value.rawValue, "CUSTOM")
	}
}
