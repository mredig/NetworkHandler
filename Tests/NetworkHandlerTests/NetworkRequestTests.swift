//
//  File.swift
//
//
//  Created by Michael Redig on 5/10/20.
//

import XCTest
@testable import NetworkHandler


/// Obviously dependent on network conditions
class NetworkRequestTests: XCTestCase {

	/// Tests encoding and decoding a request body
	func testEncodingGeneric() {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)

		let dummyURL = URL(string: "https://redeggproductions.com")!
		var request = dummyURL.request

		request.encodeData(testDummy)

		XCTAssertNotNil(request.httpBody)

		XCTAssertNoThrow(try request.decoder.decode(DummyType.self, from: request.httpBody!))
		XCTAssertEqual(testDummy, try request.decoder.decode(DummyType.self, from: request.httpBody!))
	}

}
