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

	/// Tests adding, setting, and getting header values
	func testRequestHeaders() {
		let dummyURL = URL(string: "https://redeggproductions.com")!
		var request = dummyURL.request

		request.addValue(.contentType(type: .json), forHTTPHeaderField: .commonKey(key: .contentType))
		XCTAssertEqual("application/json", request.value(forHTTPHeaderField: .commonKey(key: .contentType)))
		request.setValue(.contentType(type: .xml), forHTTPHeaderField: .commonKey(key: .contentType))
		XCTAssertEqual("application/xml", request.value(forHTTPHeaderField: .commonKey(key: .contentType)))
		request.setValue(.other(value: "Bearer: 12345"), forHTTPHeaderField: .commonKey(key: .authorization))
		XCTAssertEqual(["Content-Type": "application/xml", "Authorization": "Bearer: 12345"], request.allHeaderFields)

		request.setValue(nil, forHTTPHeaderField: .commonKey(key: .authorization))
		XCTAssertEqual(["Content-Type": "application/xml"], request.allHeaderFields)
		XCTAssertNil(request.value(forHTTPHeaderField: .commonKey(key: .authorization)))

		request.setValue(.other(value: "Arbitrary Value"), forHTTPHeaderField: .other(key: "Arbitrary Key"))
		XCTAssertEqual(["Content-Type": "application/xml", "Arbitrary Key": "Arbitrary Value"], request.allHeaderFields)

		var request2 = dummyURL.request
		request2.setValue(.contentType(type: .audioMp4), forHTTPHeaderField: .commonKey(key: .contentType))
		XCTAssertEqual("audio/mp4", request2.value(forHTTPHeaderField: .commonKey(key: .contentType)))
	}

}
