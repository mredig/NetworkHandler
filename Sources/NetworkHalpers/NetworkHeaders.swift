import Foundation
import SwiftPizzaSnips

public struct HTTPHeader: Hashable, Sendable {
	public let key: HTTPHeaderKey
	public let value: HTTPHeaderValue

	public init(key: HTTPHeaderKey, value: HTTPHeaderValue) {
		self.key = key
		self.value = value
	}
}

/// Pre-typed strings for use with formatting headers
public struct HTTPHeaderKey: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
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
}

extension HTTPHeaderKey: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String { canonical }
	public var debugDescription: String {
		"HeaderKey: \(description)"
	}
}

public struct HTTPHeaderValue:
	RawRepresentable,
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
}

extension HTTPHeaderValue: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String { value }
	public var debugDescription: String {
		"HeaderValue: \(description)"
	}
}

public struct HTTPHeaders: Hashable, Sendable, MutableCollection, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
	public var startIndex: [HTTPHeader].Index { headers.startIndex }
	public var endIndex: [HTTPHeader].Index { headers.endIndex }

	public typealias Index = [HTTPHeader].Index

	public var headers: [HTTPHeader]

	public init(_ headers: [HTTPHeader]) {
		self.headers = headers
	}

	public init(_ headers: [String: String]) {
		self.init(headers.map { HTTPHeader(key: "\($0.key)", value: "\($0.value)") })
	}

	public init(_ headers: [HTTPHeaderKey: HTTPHeaderValue]) {
		self.init(headers.map { HTTPHeader(key: $0.key, value: $0.value) })
	}

	public init(arrayLiteral elements: HTTPHeader...) {
		self.init(elements)
	}

	public init(dictionaryLiteral elements: (HTTPHeaderKey, HTTPHeaderValue)...) {
		self.init(elements.map { HTTPHeader(key: $0, value: $1) })
	}

	public func index(after i: [HTTPHeader].Index) -> [HTTPHeader].Index {
		headers.index(after: i)
	}

	public subscript(position: [HTTPHeader].Index) -> HTTPHeader {
		get { headers[position] }
		set { headers[position] = newValue }
	}

	/// Removes and optionally returns the header at the given index. Retrieving beyond the end index is illegal!
	@discardableResult
	public mutating func remove(at index: [HTTPHeader].Index) -> HTTPHeader {
		headers.remove(at: index)
	}

	/// Adds a new header to the collection. Allows for duplicating keys.
	public mutating func append(_ new: HTTPHeader) {
		headers.append(new)
	}

	public subscript (key: HTTPHeaderKey) -> HTTPHeaderValue? {
		get {
			headers.first(where: { $0.key == key })?.value
		}

		set {
			let currentIndex = headers.firstIndex(where: { $0.key == key })

			switch (currentIndex, newValue) {
			case (.some(let index), .some(let newValue)):
				let newEntry = HTTPHeader(key: key, value: newValue)
				headers[index] = newEntry
			case (.some(let index), nil):
				headers.remove(at: index)
			case (nil, .some(let newValue)):
				let newEntry = HTTPHeader(key: key, value: newValue)
				headers.append(newEntry)
			case (nil, nil):
				return
			}
		}
	}

	/// Retrieves all the indicies, including duplicates, for a given key.
	public func indicies(for key: HTTPHeaderKey) -> [[HTTPHeader].Index] {
		headers.enumerated().compactMap {
			guard $0.element.key == key else { return nil }
			return $0.offset
		}
	}

	/// Retrieves all the headers, including duplicates, for a given key.
	public func allHeaders(withKey key: HTTPHeaderKey) -> [HTTPHeader] {
		headers.filter { $0.key == key }
	}

	/// Retrieves all used keys
	public func keys() -> [HTTPHeaderKey] {
		headers.map(\.key)
	}
}

public extension HTTPHeaders {
	/// Appends the key/value pair to the headers. Allows duplicate keys.
	mutating func addValue(_ value: HTTPHeaderValue, forKey key: HTTPHeaderKey) {
		append(HTTPHeader(key: key, value: value))
	}

	/// Replaces the first instance of the given key, if it already exists. Otherwise appends.
	mutating func setValue(_ value: HTTPHeaderValue, forKey key: HTTPHeaderKey) {
		self[key] = value
	}

	/// If the provided key is in this instance, returns the value.
	func value(for key: HTTPHeaderKey) -> String? {
		self[key]?.rawValue
	}

	mutating func setContentType(_ contentType: HTTPHeaderValue) {
		setValue(contentType, forKey: .contentType)
	}

	mutating func setAuthorization(_ value: HTTPHeaderValue) {
		setValue(value, forKey: .authorization)
	}
}

public extension HTTPHeaders {
	mutating func combine(with other: HTTPHeaders) {
		headers.append(contentsOf: other.headers)
	}

	func combining(with other: HTTPHeaders) -> HTTPHeaders {
		var new = self
		new.combine(with: other)
		return new
	}

	static func + (lhs: HTTPHeaders, rhs: HTTPHeaders) -> HTTPHeaders {
		lhs.combining(with: rhs)
	}

	static func += (lhs: inout HTTPHeaders, rhs: HTTPHeaders) {
		lhs.combine(with: rhs)
	}
}

extension HTTPHeaders: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String {
		headers
			.map { "\($0.key): \($0.value)" }
			.joined(separator: "\n")
	}

	public var debugDescription: String {
		"\(Self.self):\n\(description.prefixingLines(with: "\t"))"
	}
}
