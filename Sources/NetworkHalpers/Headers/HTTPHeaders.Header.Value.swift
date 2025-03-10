public typealias HTTPHeaderValue = HTTPHeaders.Header.Value
extension HTTPHeaders.Header {
	public struct Value:
		RawRepresentable,
		Codable,
		Hashable,
		Sendable,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

		public let rawValue: String
		public var value: String { rawValue }

		public init(stringLiteral value: StringLiteralType) {
			self.rawValue = value
		}

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		// common Content-Type values
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

		public static func == (lhs: HTTPHeaderValue, rhs: String?) -> Bool {
			lhs.value == rhs
		}

		public static func == (lhs: String?, rhs: HTTPHeaderValue) -> Bool {
			rhs == lhs
		}

		public static func != (lhs: HTTPHeaderValue, rhs: String?) -> Bool {
			!(lhs == rhs)
		}

		public static func != (lhs: String?, rhs: HTTPHeaderValue) -> Bool {
			rhs != lhs
		}
	}
}

extension HTTPHeaders.Header.Value: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String { value }
	public var debugDescription: String {
		"HeaderValue: \(description)"
	}
}

extension HTTPHeaders.Header.Value: Comparable {
	public static func < (lhs: HTTPHeaders.Header.Value, rhs: HTTPHeaders.Header.Value) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}
