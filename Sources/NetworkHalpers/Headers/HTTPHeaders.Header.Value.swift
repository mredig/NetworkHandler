//public typealias Value = HTTPHeaders.Header.Value
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
		public static let javascript: Value = "application/javascript"
		public static let json: Value = "application/json"
		public static let octetStream: Value = "application/octet-stream"
		public static let xFontWoff: Value = "application/x-font-woff"
		public static let xml: Value = "application/xml"
		public static let audioMp4: Value = "audio/mp4"
		public static let ogg: Value = "audio/ogg"
		public static let opentype: Value = "font/opentype"
		public static let svgXml: Value = "image/svg+xml"
		public static let webp: Value = "image/webp"
		public static let xIcon: Value = "image/x-icon"
		public static let cacheManifest: Value = "text/cache-manifest"
		public static let vCard: Value = "text/v-card"
		public static let vtt: Value = "text/vtt"
		public static let videoMp4: Value = "video/mp4"
		public static let videoOgg: Value = "video/ogg"
		public static let webm: Value = "video/webm"
		public static let xFlv: Value = "video/x-flv"
		public static let png: Value = "image/png"
		public static let jpeg: Value = "image/jpeg"
		public static let bmp: Value = "image/bmp"
		public static let css: Value = "text/css"
		public static let gif: Value = "image/gif"
		public static let html: Value = "text/html"
		public static let audioMpeg: Value = "audio/mpeg"
		public static let videoMpeg: Value = "video/mpeg"
		public static let pdf: Value = "application/pdf"
		public static let quicktime: Value = "video/quicktime"
		public static let rtf: Value = "application/rtf"
		public static let tiff: Value = "image/tiff"
		public static let plain: Value = "text/plain"
		public static let zip: Value = "application/zip"
		public static let plist: Value = "application/x-plist"
		/// If using built in multipart form support, look into `MultipartFormInputStream.multipartContentTypeHeaderValue`
		public static func multipart(boundary: String) -> Value {
			"multipart/form-data; boundary=\(boundary)"
		}

		public static func == (lhs: Value, rhs: String?) -> Bool {
			lhs.value == rhs
		}

		public static func == (lhs: String?, rhs: Value) -> Bool {
			rhs == lhs
		}

		public static func != (lhs: Value, rhs: String?) -> Bool {
			!(lhs == rhs)
		}

		public static func != (lhs: String?, rhs: Value) -> Bool {
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
