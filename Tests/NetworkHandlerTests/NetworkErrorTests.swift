//
//  File.swift
//  
//
//  Created by Michael Redig on 5/10/20.
//

import XCTest
@testable import NetworkHandler

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
											 .urlInvalid(urlString: "he.ho.hum")]
		return allErrorCases
	}
}
