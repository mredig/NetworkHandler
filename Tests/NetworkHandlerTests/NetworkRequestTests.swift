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

		let allFields = ["Content-Type": "application/xml", "Authorization": "Bearer: 12345", "Arbitrary Key": "Arbitrary Value"]
		request.allHeaderFields = allFields
		XCTAssertEqual(allFields, request.allHeaderFields)

		var request2 = dummyURL.request
		request2.setValue(.contentType(type: .audioMp4), forHTTPHeaderField: .commonKey(key: .contentType))
		XCTAssertEqual("audio/mp4", request2.value(forHTTPHeaderField: .commonKey(key: .contentType)))
	}

	func testURLRequestMirroredProperties() {
		let dummyURL = URL(string: "https://redeggproductions.com")!
		var request = dummyURL.request

		request.cachePolicy = .returnCacheDataDontLoad
		XCTAssertEqual(.returnCacheDataDontLoad, request.cachePolicy)
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		XCTAssertEqual(.reloadIgnoringLocalAndRemoteCacheData, request.cachePolicy)

		XCTAssertEqual(dummyURL, request.url)
		let otherURL = URL(string: "https://redeggproductions.com/otherURL")
		request.url = otherURL
		XCTAssertEqual(otherURL, request.url)

		let dummyStream = InputStream(data: Data([1, 2, 3, 4, 5]))

		XCTAssertNil(request.httpBodyStream)
		request.httpBodyStream = dummyStream
		XCTAssertEqual(dummyStream, request.httpBodyStream)

		XCTAssertNil(request.mainDocumentURL)
		request.mainDocumentURL = dummyURL
		XCTAssertEqual(dummyURL, request.mainDocumentURL)

		XCTAssertEqual(60, request.timeoutInterval)
		request.timeoutInterval = 120
		XCTAssertEqual(120, request.timeoutInterval)

		request.httpShouldHandleCookies = false
		XCTAssertFalse(request.httpShouldHandleCookies)
		request.httpShouldHandleCookies = true
		XCTAssertTrue(request.httpShouldHandleCookies)

		request.httpShouldUsePipelining = false
		XCTAssertFalse(request.httpShouldUsePipelining)
		request.httpShouldUsePipelining = true
		XCTAssertTrue(request.httpShouldUsePipelining)

		request.allowsCellularAccess = false
		XCTAssertFalse(request.allowsCellularAccess)
		request.allowsCellularAccess = true
		XCTAssertTrue(request.allowsCellularAccess)

		request.networkServiceType = .avStreaming
		XCTAssertEqual(.avStreaming, request.networkServiceType)
		request.networkServiceType = .responsiveData
		XCTAssertEqual(.responsiveData, request.networkServiceType)

		#if !os(Linux)
		if #available(iOS 13.0, OSX 10.15, *) {
			request.allowsExpensiveNetworkAccess = false
			XCTAssertFalse(request.allowsExpensiveNetworkAccess)
			request.allowsExpensiveNetworkAccess = true
			XCTAssertTrue(request.allowsExpensiveNetworkAccess)

			request.allowsConstrainedNetworkAccess = false
			XCTAssertFalse(request.allowsConstrainedNetworkAccess)
			request.allowsConstrainedNetworkAccess = true
			XCTAssertTrue(request.allowsConstrainedNetworkAccess)
		}
		#endif
	}

}
