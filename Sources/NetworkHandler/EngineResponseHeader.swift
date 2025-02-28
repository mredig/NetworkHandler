import NetworkHalpers
import Foundation

public struct EngineResponseHeader: Hashable, Sendable {
	public let status: Int
	public let headers: HTTPHeaders

	public var expectedContentLength: Int64? { headers[.contentLength].flatMap { Int64($0.rawValue) } }
	public var suggestedFilename: String? {
		guard let contentDisp = headers[.contentDisposition]?.rawValue else { return nil }
		let name = contentDisp.firstMatch(of: /filename="(?<filename>[^"]+)"/)?.output.filename
		return name.map(String.init)
	}
	public var mimeType: String? { headers[.contentType]?.rawValue }
	public let url: URL?

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
