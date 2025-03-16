extension HTTPHeaders.Header {
	/// Pre-typed strings for use with formatting headers
	public struct Key:
		RawRepresentable,
		Codable,
		Hashable,
		Sendable,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

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

		/// Convenience for the `Accept` HTTP Header name
		public static let accept: Key = "Accept"
		/// Convenience for the `Accept-Charset` HTTP Header name
		public static let acceptCharset: Key = "Accept-Charset"
		/// Convenience for the `Accept-Datetime` HTTP Header name
		public static let acceptDatetime: Key = "Accept-Datetime"
		/// Convenience for the `Accept-Encoding` HTTP Header name
		public static let acceptEncoding: Key = "Accept-Encoding"
		/// Convenience for the `Accept-Language` HTTP Header name
		public static let acceptLanguage: Key = "Accept-Language"
		/// Convenience for the `Allow` HTTP Header name
		public static let allow: Key = "Allow"
		/// Convenience for the `Authorization` HTTP Header name
		public static let authorization: Key = "Authorization"
		/// Convenience for the `Cache-Control` HTTP Header name
		public static let cacheControl: Key = "Cache-Control"
		/// Convenience for the `Content-Disposition` HTTP Header name
		public static let contentDisposition: Key = "Content-Disposition"
		/// Convenience for the `Content-Encoding` HTTP Header name
		public static let contentEncoding: Key = "Content-Encoding"
		/// Convenience for the `Content-Language` HTTP Header name
		public static let contentLanguage: Key = "Content-Language"
		/// Convenience for the `Content-Length` HTTP Header name
		public static let contentLength: Key = "Content-Length"
		/// Convenience for the `Content-Location` HTTP Header name
		public static let contentLocation: Key = "Content-Location"
		/// Convenience for the `Content-Type` HTTP Header name
		public static let contentType: Key = "Content-Type"
		/// Convenience for the `Cookie` HTTP Header name
		public static let cookie: Key = "Cookie"
		/// Convenience for the `Date` HTTP Header name
		public static let date: Key = "Date"
		/// Convenience for the `Expect` HTTP Header name
		public static let expect: Key = "Expect"
		/// Convenience for the `Front-End-Https` HTTP Header name
		public static let frontEndHttps: Key = "Front-End-Https"
		/// Convenience for the `If-Match` HTTP Header name
		public static let ifMatch: Key = "If-Match"
		/// Convenience for the `If-Modified-Since` HTTP Header name
		public static let ifModifiedSince: Key = "If-Modified-Since"
		/// Convenience for the `If-None-Match` HTTP Header name
		public static let ifNoneMatch: Key = "If-None-Match"
		/// Convenience for the `If-Range` HTTP Header name
		public static let ifRange: Key = "If-Range"
		/// Convenience for the `If-Unmodified-Since` HTTP Header name
		public static let ifUnmodifiedSince: Key = "If-Unmodified-Since"
		/// Convenience for the `Max-Forwards` HTTP Header name
		public static let maxForwards: Key = "Max-Forwards"
		/// Convenience for the `Pragma` HTTP Header name
		public static let pragma: Key = "Pragma"
		/// Convenience for the `Proxy-Authorization` HTTP Header name
		public static let proxyAuthorization: Key = "Proxy-Authorization"
		/// Convenience for the `Proxy-Connection` HTTP Header name
		public static let proxyConnection: Key = "Proxy-Connection"
		/// Convenience for the `Range` HTTP Header name
		public static let range: Key = "Range"
		/// Convenience for the `Referer` HTTP Header name
		public static let referer: Key = "Referer"
		/// Convenience for the `Server` HTTP Header name
		public static let server: Key = "Server"
		/// Convenience for the `Set-Cookie` HTTP Header name
		public static let setCookie: Key = "Set-Cookie"
		/// Convenience for the `TE` HTTP Header name
		public static let TE: Key = "TE"
		/// Convenience for the `Upgrade` HTTP Header name
		public static let upgrade: Key = "Upgrade"
		/// Convenience for the `User-Agent` HTTP Header name
		public static let userAgent: Key = "User-Agent"
		/// Convenience for the `Via` HTTP Header name
		public static let via: Key = "Via"
		/// Convenience for the `Warning` HTTP Header name
		public static let warning: Key = "Warning"
		/// Convenience for the `X-Request-ID` HTTP Header name
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
