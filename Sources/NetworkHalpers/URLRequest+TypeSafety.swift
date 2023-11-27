import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URLRequest {
	/// A typesafe alternative to `httpMethod`. You can set and compare your values to guaranteed correct values 
	/// like `.get` and `.post`
	var method: HTTPMethod? {
		get { httpMethod.map(HTTPMethod.init(stringLiteral:)) }
		set { httpMethod = newValue?.rawValue }
	}

	var allHTTPHeaders: [HTTPHeaderKey: HTTPHeaderValue] {
		let unwrapped = allHTTPHeaderFields ?? [:]
		let typedKeys = unwrapped
			.keys
			.map { HTTPHeaderKey(stringLiteral: $0) }
		let typedHeaders: [HTTPHeaderKey: HTTPHeaderValue] = typedKeys
			.reduce(into: [HTTPHeaderKey: HTTPHeaderValue]()) {
				guard let value = unwrapped[$1.rawValue] else { return }
				$0[$1] = HTTPHeaderValue(rawValue: value)
			}
		return typedHeaders
	}

	mutating func addValue(_ headerValue: HTTPHeaderValue, forHTTPHeaderField key: HTTPHeaderKey) {
		let strKey = key.key

		addValue(headerValue.value, forHTTPHeaderField: strKey)
	}

	mutating func setValue(_ headerValue: HTTPHeaderValue?, forHTTPHeaderField key: HTTPHeaderKey) {
		let strKey = key.key

		guard let headerValue = headerValue else {
			setValue(nil, forHTTPHeaderField: strKey)
			return
		}
		setValue(headerValue.value, forHTTPHeaderField: strKey)
	}

	func value(forHTTPHeaderField key: HTTPHeaderKey) -> String? {
		let strKey = key.key
		return value(forHTTPHeaderField: strKey)
	}

	mutating func setContentType(_ contentType: HTTPHeaderValue) {
		setValue(contentType, forHTTPHeaderField: .contentType)
	}

	mutating func setAuthorization(_ value: HTTPHeaderValue) {
		setValue(value, forHTTPHeaderField: .authorization)
	}

	/**
	Default encoder used to encode with the `encodeData` function. Changes here will reflect all requests that don't 
	provide their own encoder going forward.

	Default value is `JSONEncoder()` along with all of its defaults.
	*/
	static var defaultEncoder: NHEncoder = JSONEncoder()

	/// Sets `.httpBody` data to the result of encoding an encodable object passed in. If successful, returns the data.
	@discardableResult mutating func encodeData<EncodableType: Encodable>(
		_ encodableType: EncodableType,
		encoder: NHEncoder? = nil
	) throws -> Data {
		if method == .get {
			NSLog("Attempt to populate a GET request http body. Used on \(type(of: encodableType))")
		}
		if value(forHTTPHeaderField: .contentType) == nil {
			NSLog("""
				You are encoding data without declaring a content-type in your request header. Used \
				on \(type(of: encodableType))
				""")
		}

		let encoder = encoder ?? Self.defaultEncoder
		let data = try encoder.encode(encodableType)
		httpBody = data
		return data
	}
}
