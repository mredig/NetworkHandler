import XCTest
@testable import NetworkHandler
@testable import TestSupport

/// Obviously dependent on network conditions
class NetworkErrorTests: XCTestCase {

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

		var error = NetworkError.badData(sourceData: testData)
		let testString = String(data: testData!, encoding: .utf8)!
		let error1Str = "NetworkError: BadData (\(testString))"

		XCTAssertEqual(error1Str, error.debugDescription)

		error = .httpNon200StatusCode(code: 401, data: testData)
		let error2Str = "NetworkError: Bad Response Code (401) with data: \(testString)"
		XCTAssertEqual(error2Str, error.debugDescription)

		error = .badData(sourceData: nil)
		let error3Str = "NetworkError: BadData (nil value)"
		XCTAssertEqual(error3Str, error.debugDescription)
	}
}

extension NetworkError {
	/// Creates a collection of Network errors covering most of the spectrum
	static func allErrorCases() -> [NetworkError] {
		let dummyError = NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil)
		let allErrorCases: [NetworkError] = [.badData(sourceData: nil),
											 .databaseFailure(specifically: dummyError),
											 .dataCodingError(specifically: dummyError, sourceData: nil),
											 .dataWasNull,
											 .httpNon200StatusCode(code: 404, data: nil),
											 .imageDecodeError,
											 .noStatusCodeResponse,
											 .otherError(error: dummyError),
											 .urlInvalid(urlString: "he.ho.hum"),
											 .urlInvalid(urlString: nil),
											 .unspecifiedError(reason: "Who knows what the error might be?!"),
											 .unspecifiedError(reason: nil),
											 .graphQLError(error: GQLError(message: "much error",
																		   path: nil,
																		   locations: nil,
																		   extensions: .init(code: "Such Extension", exception: nil)))
		]
		return allErrorCases
	}
}
