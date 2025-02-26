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
		#expect(b == c)
		#expect(b == d)
		#expect(c == d)
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
}
