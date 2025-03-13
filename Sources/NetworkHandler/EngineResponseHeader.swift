import NetworkHalpers
import Foundation

/// Represents the metadata of an HTTP response, including the status code, headers,
/// and additional derived properties for easier access to common response attributes.
///
/// This is the lowest common denominator of a response header, needed as a result of
/// conforming to `NetworkEngine` method requirements. It is recommended to
/// extend `EngineResponseHeader` with a convenience initializer consuming the
/// native response header type for your engine.
public struct EngineResponseHeader: Hashable, Sendable, Codable {
	/// The HTTP status code of the response. Indicates the outcome of the request,
	/// such as `200` for success or `404` for not found.
	public let status: Int
	/// The collection of HTTP headers returned in the response.
	/// Provides access to both raw header values and convenience properties such as
	/// `expectedContentLength` and `mimeType` derived from specific headers.
	public let headers: HTTPHeaders

	/// Extracts the `Content-Length` header value and converts it to a `Int64`, if present.
	/// Represents the expected size of the HTTP response body in bytes.
	public var expectedContentLength: Int64? { headers[.contentLength].flatMap { Int64($0.rawValue) } }
	/// Extracts a suggested filename from the `Content-Disposition` header, if provided.
	///
	/// This is commonly used to determine a file name when downloading an attachment from the server.
	/// The value is parsed from the header using a regular expression to locate the `filename` attribute.
	///
	/// - Returns: The suggested filename as a `String`, or `nil` if the header is not present or improperly formatted.
	public var suggestedFilename: String? {
		guard let contentDisp = headers[.contentDisposition]?.rawValue else { return nil }
		let name = contentDisp.firstMatch(of: /filename="(?<filename>[^"]+)"/)?.output.filename
		return name.map(String.init)
	}
	/// Extracts the `Content-Type` header value, which specifies the MIME type of the response data.
	///
	/// Common MIME types:
	/// - `application/json`
	/// - `text/plain`
	/// - `image/jpeg`
	///
	/// - Returns: The MIME type as a `String`, or `nil` if the header is not present.
	public var mimeType: String? { headers[.contentType]?.rawValue }
	/// The final URL for the response. This value may differ from the original request's URL
	/// if redirects occurred during the network operation.
	///
	/// For example, a request to `http://example.com` might redirect to
	/// `https://www.example.com`, and this property would reflect the final resolved URL.
	public let url: URL?

	/// Initializes a new instance of `EngineResponseHeader`.
	///
	/// - Parameters:
	///   - status: The HTTP status code of the response, such as `200`.
	///   - url: The final URL for the response, accounting for any redirects.
	///   - headers: The HTTP headers returned in the response.
	public init(status: Int, url: URL?, headers: HTTPHeaders) {
		self.status = status
		self.headers = headers
		self.url = url
	}
}

extension EngineResponseHeader: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String {
		var accumulator: [String] = []

		accumulator.append("Status - \(status)")
		if let url {
			accumulator.append("URL - \(url)")
		}
		if let expectedContentLength {
			accumulator.append("Expected length - \(expectedContentLength)")
		}
		if let mimeType {
			accumulator.append("MIME Type - \(mimeType)")
		}
		if let suggestedFilename {
			accumulator.append("Suggested Filename - \(suggestedFilename)")
		}
		accumulator.append("All Headers:")
		accumulator.append(headers.description.prefixingLines(with: "\t"))

		accumulator = accumulator.map { $0.prefixingLines(with: "\t") }
		accumulator = ["EngineResponse:"] + accumulator

		return accumulator.joined(separator: "\n")
	}

	public var debugDescription: String {
		description
	}
}
