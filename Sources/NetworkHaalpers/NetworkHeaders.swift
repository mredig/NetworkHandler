import Foundation

public struct HTTPHeader: Hashable {
	let key: HTTPHeaderKey
	let value: HTTPHeaderValue
}

/// Pre-typed strings for use with formatting headers
public struct HTTPHeaderKey: RawRepresentable, Hashable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
	public var key: String { rawValue }
	public let rawValue: String

	public init(stringLiteral value: StringLiteralType) {
		self.rawValue = value
	}

	public init?(rawValue: String) {
		self.rawValue = rawValue
	}

	public static let accept: HTTPHeaderKey = "Accept"
	public static let acceptEncoding: HTTPHeaderKey = "Accept-Encoding"
	public static let authorization: HTTPHeaderKey = "Authorization"
	public static let contentType: HTTPHeaderKey = "Content-Type"
	public static let acceptCharset: HTTPHeaderKey = "Accept-Charset"
	public static let acceptDatetime: HTTPHeaderKey = "Accept-Datetime"
	public static let acceptLanguage: HTTPHeaderKey = "Accept-Language"
	public static let cacheControl: HTTPHeaderKey = "Cache-Control"
	public static let date: HTTPHeaderKey = "Date"
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
	public static let TE: HTTPHeaderKey = "TE"
	public static let upgrade: HTTPHeaderKey = "Upgrade"
	public static let userAgent: HTTPHeaderKey = "User-Agent"
	public static let via: HTTPHeaderKey = "Via"
	public static let warning: HTTPHeaderKey = "Warning"
	public static let frontEndHttps: HTTPHeaderKey = "Front-End-Https"
	public static let cookie: HTTPHeaderKey = "Cookie"
	public static let expect: HTTPHeaderKey = "Expect"

	public static func ==(lhs: HTTPHeaderKey, rhs: String?) -> Bool {
		lhs.key == rhs
	}

	public static func ==(lhs: String?, rhs: HTTPHeaderKey) -> Bool {
		rhs == lhs
	}
}

public struct HTTPHeaderValue: RawRepresentable, Hashable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
	public let rawValue: String
	public var value: String { rawValue }

	public init(stringLiteral value: StringLiteralType) {
		self.rawValue = value
	}

	public init?(rawValue: String) {
		self.rawValue = rawValue
	}

	public static let javascript: HTTPHeaderValue = "application/javascript"
	public static let json: HTTPHeaderValue = "application/json"
	public static let octetStream: HTTPHeaderValue = "application/octet-stream"
	public static let xFontWoff: HTTPHeaderValue = "application/x-font-woff"
	public static let xml: HTTPHeaderValue = "application/xml"
	public static let audioMp4: HTTPHeaderValue = "audio/mp4"
	public static let ogg: HTTPHeaderValue = "audio/ogg"
	public static let opentype: HTTPHeaderValue = "font/opentype"
	public static let svgXml: HTTPHeaderValue = "image/svg+xml"
	public static let webp: HTTPHeaderValue = "image/webp"
	public static let xIcon: HTTPHeaderValue = "image/x-icon"
	public static let cacheManifest: HTTPHeaderValue = "text/cache-manifest"
	public static let vCard: HTTPHeaderValue = "text/v-card"
	public static let vtt: HTTPHeaderValue = "text/vtt"
	public static let videoMp4: HTTPHeaderValue = "video/mp4"
	public static let videoOgg: HTTPHeaderValue = "video/ogg"
	public static let webm: HTTPHeaderValue = "video/webm"
	public static let xFlv: HTTPHeaderValue = "video/x-flv"
	public static let png: HTTPHeaderValue = "image/png"
	public static let jpeg: HTTPHeaderValue = "image/jpeg"
	public static let bmp: HTTPHeaderValue = "image/bmp"
	public static let css: HTTPHeaderValue = "text/css"
	public static let gif: HTTPHeaderValue = "image/gif"
	public static let html: HTTPHeaderValue = "text/html"
	public static let audioMpeg: HTTPHeaderValue = "audio/mpeg"
	public static let videoMpeg: HTTPHeaderValue = "video/mpeg"
	public static let pdf: HTTPHeaderValue = "application/pdf"
	public static let quicktime: HTTPHeaderValue = "video/quicktime"
	public static let rtf: HTTPHeaderValue = "application/rtf"
	public static let tiff: HTTPHeaderValue = "image/tiff"
	public static let plain: HTTPHeaderValue = "text/plain"
	public static let zip: HTTPHeaderValue = "application/zip"
	public static let plist: HTTPHeaderValue = "application/x-plist"
	/// If using built in multipart form support, look into `MultipartFormInputStream.multipartContentTypeHeaderValue`
	public static func multipart(boundary: String) -> HTTPHeaderValue {
		"multipart/form-data; boundary=\(boundary)"
	}

	public static func ==(lhs: HTTPHeaderValue, rhs: String?) -> Bool {
		lhs.value == rhs
	}

	public static func ==(lhs: String?, rhs: HTTPHeaderValue) -> Bool {
		rhs == lhs
	}
}

