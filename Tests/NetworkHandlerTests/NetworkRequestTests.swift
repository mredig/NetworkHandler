import Testing
import NetworkHandler
import TestSupport
import PizzaMacros
import Foundation

struct NetworkRequestTests {
	@Test func genericEncoding() async throws {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)

		let dummyURL = #URL("https://redeggproductions.com")
		let request = try dummyURL.downloadRequest.with {
			try $0.encodeData(testDummy)
		}

		let data = try #require(request.payload)

		let decoded = try GeneralEngineRequest.defaultDecoder.decode(DummyType.self, from: data)
		#expect(decoded == testDummy)
	}

	/// Tests adding, setting, and getting header values
	@Test func requestHeaders() {
		let dummyURL = #URL("https://redeggproductions.com")
		let origRequest = dummyURL.downloadRequest.with {
			$0.requestID = nil
		}
		var request = NetworkRequest.download(origRequest)

		request.headers.addValue(.json, forKey: .contentType)
		#expect("application/json" == request.headers[.contentType])
		request.headers.setValue(.xml, forKey: .contentType)
		#expect("application/xml" == request.headers[.contentType])
		request.headers.setValue("Bearer: 12345", forKey: .authorization)
		#expect(["Content-Type": "application/xml", "Authorization": "Bearer: 12345"] == request.headers)

		request.headers.setValue(nil, forKey: .authorization)
		#expect(["Content-Type": "application/xml"] == request.headers)
		#expect(request.headers[.authorization] == nil)

		request.headers.setValue("Arbitrary Value", forKey: "Arbitrary Key")
		#expect(["Content-Type": "application/xml", "arbitrary key": "Arbitrary Value"] == request.headers)

		let allFields: HTTPHeaders = [
			"Content-Type": "application/xml",
			"Authorization": "Bearer: 12345",
			"Arbitrary Key": "Arbitrary Value",
		]
		request.headers = allFields
		#expect(allFields == request.headers)

		var request2 = dummyURL.downloadRequest.with {
			$0.requestID = nil
		}
		request2.headers.setValue(.audioMp4, forKey: .contentType)
		#expect("audio/mp4" == request2.headers.value(for: .contentType))

		request2.headers.setContentType(.bmp)
		#expect("image/bmp" == request2.headers.value(for: .contentType))

		request2.headers.setAuthorization("Bearer asdlkqf")
		#expect("Bearer asdlkqf" == request2.headers.value(for: .authorization))
	}

	@Test func requestHeadersWithDuplicates() async throws {
		let dummyURL = #URL("https://redeggproductions.com")
		var requestWithNoDup = dummyURL.downloadRequest.with {
			$0.requestID = nil
		}
		requestWithNoDup.headers.addValue("sessionId=abc123", forKey: .cookie)

		var requestWithDup = requestWithNoDup
		requestWithDup.headers.addValue("foo=bar", forKey: .cookie)

		#expect(requestWithDup != requestWithNoDup)
		#expect(requestWithDup.headers.count == 2)
		#expect(requestWithNoDup.headers.count == 1)
	}

	@Test func requestHeadersWithDuplicatesAddedInDifferentOrder() async throws {
		let dummyURL = #URL("https://redeggproductions.com")
		var request1 = dummyURL.downloadRequest.with {
			$0.requestID = nil
		}
		var request2 = request1

		request1.headers.addValue("sessionId=abc123", forKey: .cookie)
		request1.headers.addValue("foo=bar", forKey: .cookie)
		request2.headers.addValue("foo=bar", forKey: .cookie)
		request2.headers.addValue("sessionId=abc123", forKey: .cookie)

		#expect(request1 == request2)
		#expect(request1.headers.count == 2)
		#expect(request2.headers.count == 2)
	}

	@Test func headerKeysAndValuesEquatableWithString() {
		let contentKey = HTTPHeaders.Header.Key.contentType

		let nilString: String? = nil

		#expect("Content-Type" == contentKey)
		#expect(contentKey == "Content-Type")
		#expect("Content-Typo" != contentKey)
		#expect(contentKey != "Content-Typo")
		#expect(contentKey != nilString)

		let gif = HTTPHeaders.Header.Value.gif

		#expect("image/gif" == gif)
		#expect(gif == "image/gif")
		#expect("image/jif" != gif)
		#expect(gif != "image/jif")
		#expect(gif != nilString)
	}

	@Test func requestID() throws {
		let dummyURL = #URL("https://redeggproductions.com")

		let downRequest = dummyURL.downloadRequest
		#expect(downRequest.requestID != nil)

		let upRequest = dummyURL.uploadRequest
		#expect(upRequest.requestID != nil)
	}
}
