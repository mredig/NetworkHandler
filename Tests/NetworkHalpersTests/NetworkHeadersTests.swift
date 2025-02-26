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
}
