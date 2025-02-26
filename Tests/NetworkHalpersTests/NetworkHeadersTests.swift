import Testing
import NetworkHalpers

struct NetworkHeadersTests {
	@Test func keys() async throws {
		let a = HTTPHeaderKey(rawValue: "Content-Type")
		let b: HTTPHeaderKey = "Content-Type"
		let c: HTTPHeaderKey = .contentType
		let d = HTTPHeaderKey(rawValue: "content-type")

		#expect(a == b)
		#expect(a == c)
		#expect(a == d)
		#expect(a.canonical != d.canonical)
		#expect(b == c)
		#expect(b == d)
		#expect(b.canonical != d.canonical)
		#expect(c == d)
		#expect(c.canonical != d.canonical)
		#expect(Set([a, b, c, d]).count == 1)

		#expect("content-Type" == a)
		#expect("Content-Type" == a)
		#expect("content-Type" == d)
		#expect("Content-Type" == d)
	}

	@Test func values() async throws {
		let a = HTTPHeaderValue(rawValue: "image/jpeg")
		let b: HTTPHeaderValue = "image/jpeg"
		let c: HTTPHeaderValue = .jpeg
		let d = HTTPHeaderValue(rawValue: "image/JPEG")

		#expect(a == b)
		#expect(a == c)
		#expect(a != d)
		#expect(b == c)
		#expect(b != d)
		#expect(c != d)
		#expect(Set([a, b, c, d]).count == 2)

		#expect("image/jpeg" == a)
		#expect("image/JPEG" != a)
		#expect("image/jpeg" != d)
		#expect("image/JPEG" == d)
	}

	@Test func multipartValue() async throws {
		let value = HTTPHeaderValue.multipart(boundary: "f0o")

		#expect("multipart/form-data; boundary=f0o" == value)
	}

	@Test func headersStringDict() async throws {
		let simpleSample = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15",
		]

		let dupedSample = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15",
			"content-type": "application/json",
		]

		let userAgentValue = HTTPHeaderValue(rawValue: simpleSample["User-Agent"]!)

		let simpleHeaders = HTTPHeaders(simpleSample)
		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.keys().count == 3)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 1)

		let dupedHeaders = HTTPHeaders(dupedSample)
		#expect(dupedHeaders[.contentType] == "application/json")
		#expect(dupedHeaders[.authorization] == "Bearer foobar")
		#expect(dupedHeaders[.userAgent] == userAgentValue)
		#expect(dupedHeaders.keys().count == 4)
		#expect(dupedHeaders.allHeaders(withKey: .contentType).count == 2)
	}

	@Test func headersHeaderDict() async throws {
		let simpleSample: [HTTPHeaderKey: HTTPHeaderValue] = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15",
		]

		let userAgentValue = simpleSample["User-Agent"]!

		let simpleHeaders = HTTPHeaders(simpleSample)
		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.keys().count == 3)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 1)
	}

	@Test func headersArrayLiteral() async throws {
		let simpleHeaders: HTTPHeaders = [
			HTTPHeader(key: "Content-Type", value: "application/json"),
			HTTPHeader(key: "Authorization", value: "Bearer foobar"),
			HTTPHeader(key: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"),
		]

		let userAgentValue = simpleHeaders["User-Agent"]!

		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.keys().count == 3)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 1)
	}

	@Test func headersDictLiteral() async throws {
		let simpleHeaders: HTTPHeaders = [
			HTTPHeaderKey(rawValue: "Content-Type"): HTTPHeaderValue(rawValue: "application/json"),
			HTTPHeaderKey(rawValue: "Authorization"): HTTPHeaderValue(rawValue: "Bearer foobar"),
			HTTPHeaderKey(rawValue: "User-Agent"): HTTPHeaderValue(rawValue: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"),
		]

		let userAgentValue = simpleHeaders["User-Agent"]!

		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.keys().count == 3)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 1)
	}

	@Test func headersMutation() async throws {
		var simpleHeaders: HTTPHeaders = [
			HTTPHeader(key: "Content-Type", value: "application/json"),
			HTTPHeader(key: "Authorization", value: "Bearer foobar"),
			HTTPHeader(key: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"),
		]

		#expect(simpleHeaders.keys().count == 3)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 1)

		simpleHeaders.append(HTTPHeader(key: .contentType, value: "application/json"))
		#expect(simpleHeaders.keys().count == 4)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 2)
		let contentIndicies = simpleHeaders.indicies(for: .contentType)
		#expect(contentIndicies == [0, 3])
		contentIndicies.reversed().forEach { simpleHeaders.remove(at: $0) }
		#expect(simpleHeaders.keys().count == 2)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 0)
	}

	@Test func headersSubscripts() async throws {
		var simpleHeaders: HTTPHeaders = [
			HTTPHeader(key: "Content-Type", value: "application/json"),
			HTTPHeader(key: "Authorization", value: "Bearer foobar"),
			HTTPHeader(key: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"),
		]

		#expect(simpleHeaders.keys().count == 3)
		#expect(simpleHeaders.allHeaders(withKey: .contentType).count == 1)
		#expect(simpleHeaders[.contentType] == "application/json")
		
		simpleHeaders[.contentType] = "application/json2"
		#expect(simpleHeaders[.contentType] == "application/json2")

		simpleHeaders[.accept] = .xml
		#expect(simpleHeaders[.accept] == .xml)

		simpleHeaders[.accept] = nil
		#expect(simpleHeaders[.accept] == nil)

		simpleHeaders[.accept] = nil
		#expect(simpleHeaders[.accept] == nil)
	}

	@Test func headersIndicies() async throws {
		var simpleHeaders: HTTPHeaders = [
			HTTPHeader(key: "Content-Type", value: "application/json"),
			HTTPHeader(key: "Authorization", value: "Bearer foobar"),
			HTTPHeader(key: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"),
		]

		#expect(simpleHeaders[0] == HTTPHeader(key: .contentType, value: .json))

		simpleHeaders[0] = HTTPHeader(key: .contentType, value: "application/json2")
		#expect(simpleHeaders[0] == HTTPHeader(key: .contentType, value: "application/json2"))

		#expect(simpleHeaders.index(after: 0) == 1)
		#expect(simpleHeaders.startIndex == 0)
		#expect(simpleHeaders.endIndex == 3)
	}
}
