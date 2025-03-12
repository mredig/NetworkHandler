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

		public static let accept: Key = "Accept"
		public static let acceptCharset: Key = "Accept-Charset"
		public static let acceptDatetime: Key = "Accept-Datetime"
		public static let acceptEncoding: Key = "Accept-Encoding"
		public static let acceptLanguage: Key = "Accept-Language"
		public static let allow: Key = "Allow"
		public static let authorization: Key = "Authorization"
		public static let cacheControl: Key = "Cache-Control"
		public static let contentDisposition: Key = "Content-Disposition"
		public static let contentEncoding: Key = "Content-Encoding"
		public static let contentLanguage: Key = "Content-Language"
		public static let contentLength: Key = "Content-Length"
		public static let contentLocation: Key = "Content-Location"
		public static let contentType: Key = "Content-Type"
		public static let cookie: Key = "Cookie"
		public static let date: Key = "Date"
		public static let expect: Key = "Expect"
		public static let frontEndHttps: Key = "Front-End-Https"
		public static let ifMatch: Key = "If-Match"
		public static let ifModifiedSince: Key = "If-Modified-Since"
		public static let ifNoneMatch: Key = "If-None-Match"
		public static let ifRange: Key = "If-Range"
		public static let ifUnmodifiedSince: Key = "If-Unmodified-Since"
		public static let maxForwards: Key = "Max-Forwards"
		public static let pragma: Key = "Pragma"
		public static let proxyAuthorization: Key = "Proxy-Authorization"
		public static let proxyConnection: Key = "Proxy-Connection"
		public static let range: Key = "Range"
		public static let referer: Key = "Referer"
		public static let server: Key = "Server"
		public static let setCookie: Key = "Set-Cookie"
		public static let TE: Key = "TE"
		public static let upgrade: Key = "Upgrade"
		public static let userAgent: Key = "User-Agent"
		public static let via: Key = "Via"
		public static let warning: Key = "Warning"
		public static let xRequestID: Key = "X-Request-ID"

		public static func == (lhs: Key, rhs: Key) -> Bool {
			lhs.key == rhs.key
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(key)
		}

		public static func == (lhs: Key, rhs: String?) -> Bool {
			lhs.key == rhs?.lowercased()
		}

		public static func == (lhs: String?, rhs: Key) -> Bool {
			rhs == lhs
		}

		public static func != (lhs: Key, rhs: String?) -> Bool {
			!(lhs == rhs)
		}

		public static func != (lhs: String?, rhs: Key) -> Bool {
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
