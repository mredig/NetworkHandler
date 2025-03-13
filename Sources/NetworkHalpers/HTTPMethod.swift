import Foundation
import SwiftPizzaSnips

/// Pre-typed strings for use with `NetworkRequest`, `GeneralEngineRequest`, and `UploadEngineRequest`
public struct HTTPMethod:
	RawRepresentable,
	Sendable,
	Hashable,
	Withable,
	ExpressibleByStringLiteral,
	ExpressibleByStringInterpolation {

	public let rawValue: String

	public init?(rawValue: String) {
		self.rawValue = rawValue
	}

	public init(stringLiteral value: String) {
		self.rawValue = value
	}
	
	/// Convenience for the `POST` HTTP method
	static public let post: HTTPMethod = "POST"
	/// Convenience for the `PUT` HTTP method
	static public let put: HTTPMethod = "PUT"
	/// Convenience for the `DELETE` HTTP method
	static public let delete: HTTPMethod = "DELETE"
	/// Convenience for the `GET` HTTP method
	static public let get: HTTPMethod = "GET"
	/// Convenience for the `HEAD` HTTP method
	static public let head: HTTPMethod = "HEAD"
	/// Convenience for the `PATCH` HTTP method
	static public let patch: HTTPMethod = "PATCH"
	/// Convenience for the `OPTIONS` HTTP method
	static public let options: HTTPMethod = "OPTIONS"
}
