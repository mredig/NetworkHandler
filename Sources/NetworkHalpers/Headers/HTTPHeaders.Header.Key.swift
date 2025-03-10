public typealias HTTPHeaderKey = HTTPHeaders.Header.Key
extension HTTPHeaders.Header {
	/// Pre-typed strings for use with formatting headers
	public struct Key: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
		/// A normalized, lowercased version of the `canonical` value. This allows for case insensitive equality and hashing.
		public var key: String { rawValue }
		/// Required for `RawRepresentable`. Duplicates the `key` value.
		public var rawValue: String { canonical.lowercased() }
		/// Value that will be stored as the key in the HTTP Header.
		public var canonical: String

		public init(stringLiteral value: StringLiteralType) {
			self.init(rawValue: value)
		}

		public init(rawValue: String) {
			self.canonical = rawValue
		}

		public static let accept: HTTPHeaderKey = "Accept"
		public static let acceptCharset: HTTPHeaderKey = "Accept-Charset"
		public static let acceptDatetime: HTTPHeaderKey = "Accept-Datetime"
		public static let acceptEncoding: HTTPHeaderKey = "Accept-Encoding"
		public static let acceptLanguage: HTTPHeaderKey = "Accept-Language"
		public static let allow: HTTPHeaderKey = "Allow"
		public static let authorization: HTTPHeaderKey = "Authorization"
		public static let cacheControl: HTTPHeaderKey = "Cache-Control"
		public static let contentDisposition: HTTPHeaderKey = "Content-Disposition"
		public static let contentEncoding: HTTPHeaderKey = "Content-Encoding"
		public static let contentLanguage: HTTPHeaderKey = "Content-Language"
		public static let contentLength: HTTPHeaderKey = "Content-Length"
		public static let contentLocation: HTTPHeaderKey = "Content-Location"
		public static let contentType: HTTPHeaderKey = "Content-Type"
		public static let cookie: HTTPHeaderKey = "Cookie"
		public static let date: HTTPHeaderKey = "Date"
		public static let expect: HTTPHeaderKey = "Expect"
		public static let frontEndHttps: HTTPHeaderKey = "Front-End-Https"
		public static let ifMatch: HTTPHeaderKey = "If-Match"
		public static let ifModifiedSince: HTTPHeaderKey = "If-Modified-Since"
		public static let ifNoneMatch: HTTPHeaderKey = "If-None-Match"
		public static let ifRange: HTTPHeaderKey = "If-Range"
		public static let ifUnmodifiedSince: HTTPHeaderKey = "If-Unmodified-Since"
		public static let maxForwards: HTTPHeaderKey = "Max-Forwards"
		public static let pragma: HTTPHeaderKey = "Pragma"
		public static let proxyAuthorization: HTTPHeaderKey = "Proxy-Authorization"
		public static let proxyConnection: HTTPHeaderKey = "Proxy-Connection"
		public static let range: HTTPHeaderKey = "Range"
		public static let referer: HTTPHeaderKey = "Referer"
		public static let server: HTTPHeaderKey = "Server"
		public static let setCookie: HTTPHeaderKey = "Set-Cookie"
		public static let TE: HTTPHeaderKey = "TE"
		public static let upgrade: HTTPHeaderKey = "Upgrade"
		public static let userAgent: HTTPHeaderKey = "User-Agent"
		public static let via: HTTPHeaderKey = "Via"
		public static let warning: HTTPHeaderKey = "Warning"
		public static let xRequestID: HTTPHeaderKey = "X-Request-ID"

		public static func == (lhs: HTTPHeaderKey, rhs: HTTPHeaderKey) -> Bool {
			lhs.key == rhs.key
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(key)
		}

		public static func == (lhs: HTTPHeaderKey, rhs: String?) -> Bool {
			lhs.key == rhs?.lowercased()
		}

		public static func == (lhs: String?, rhs: HTTPHeaderKey) -> Bool {
			rhs == lhs
		}

		public static func != (lhs: HTTPHeaderKey, rhs: String?) -> Bool {
			!(lhs == rhs)
		}

		public static func != (lhs: String?, rhs: HTTPHeaderKey) -> Bool {
			rhs != lhs
		}
	}
}

extension HTTPHeaders.Header.Key: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String { canonical }
	public var debugDescription: String {
		"HeaderKey: \(description)"
	}
}

extension HTTPHeaders.Header.Key: Comparable {
	public static func < (lhs: HTTPHeaders.Header.Key, rhs: HTTPHeaders.Header.Key) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}
