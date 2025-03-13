import XCTest
import NetworkHandler
@testable import TestSupport
import PizzaMacros

/// Obviously dependent on network conditions
class NetworkErrorTests: XCTestCase {
	static let simpleURL = #URL("http://he@ho.hum")

	// MARK: - Template/Prototype Objects
	/// Tests Equatability on NetworkError cases
	func testErrorEquatable() {
		let allErrors = NetworkError.allErrorCases()
		let dupErrors = NetworkError.allErrorCases()
		var rotErrors = NetworkError.allErrorCases()
		let rot1 = rotErrors.remove(at: 0)
		rotErrors.append(rot1)

		for (index, error) in allErrors.enumerated() {
			XCTAssertEqual(error, dupErrors[index])
			XCTAssertNotEqual(error, rotErrors[index])
		}
	}

	@available(iOS 11.0, macOS 13.0, *)
	func testErrorOutput() {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		let testData = try? encoder.encode(testDummy)

		var error = NetworkError.unspecifiedError(reason: "Foo bar")
		let testString = String(data: testData!, encoding: .utf8)!
		let error1Str = "NetworkError: Unspecified Error: Foo bar"

		XCTAssertEqual(error1Str, error.debugDescription)

		error = .httpUnexpectedStatusCode(code: 401, originalRequest: .general(Self.simpleURL.generalRequest).with { $0.requestID = nil }, data: testData)
		let error2Str = "NetworkError: Bad Response Code (401) for request: (GET): http://he@ho.hum with data: \(testString)"
		XCTAssertEqual(error2Str, error.debugDescription)

		error = NetworkError.unspecifiedError(reason: nil)
		let error3Str = "NetworkError: Unspecified Error: nil value"
		XCTAssertEqual(error3Str, error.debugDescription)
	}
}

extension NetworkError {
	/// Creates a collection of Network errors covering most of the spectrum
	static func allErrorCases() -> [NetworkError] {
		let dummyError = NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil)
		let originalRequest = NetworkRequest.general(NetworkErrorTests.simpleURL.generalRequest).with {
			$0.requestID = nil
		}
		let allErrorCases: [NetworkError] = [
			.dataCodingError(specifically: dummyError, sourceData: nil),
			.httpUnexpectedStatusCode(code: 404, originalRequest: originalRequest, data: nil),
			.unspecifiedError(reason: "Who knows what the error might be?!"),
			.unspecifiedError(reason: nil),
			.requestTimedOut,
			.otherError(error: dummyError),
			.requestCancelled,
			.noData,
		]
		return allErrorCases
	}
}
