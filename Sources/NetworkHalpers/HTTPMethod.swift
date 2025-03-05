import Foundation
import SwiftPizzaSnips
//#if canImport(FoundationNetworking)
//import FoundationNetworking
//#endif

/// Pre-typed strings for use with NetworkRequest.httpMethod (or URLRequest.httpMethod)
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

	static public let post: HTTPMethod = "POST"
	static public let put: HTTPMethod = "PUT"
	static public let delete: HTTPMethod = "DELETE"
	static public let get: HTTPMethod = "GET"
	static public let head: HTTPMethod = "HEAD"
	static public let patch: HTTPMethod = "PATCH"
	static public let options: HTTPMethod = "OPTIONS"
}
