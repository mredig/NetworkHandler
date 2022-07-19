import Foundation
import CoreServices
import UniformTypeIdentifiers

extension MultipartFormInputTempFile {
	struct Part {
		var headers: Data {
			headersString.data(using: .utf8) ?? Data(headersString.utf8)
		}
		var headersString: String {
			var out = "--\(boundary)\r\n"

			var contentDispositionInfo: [String] = []
			if content != nil {
				contentDispositionInfo.append("Content-Disposition: form-data")
			}
			if let name = name {
				contentDispositionInfo.append("name=\"\(name)\"")
			}
			if let filename = filename {
				contentDispositionInfo.append("filename=\"\(filename)\"")
			}
			out += contentDispositionInfo.joined(separator: "; ")

			if let contentType = contentType {
				out += "\r\nContent-Type: \(contentType)\r\n\r\n"
			} else {
				out += "\r\n\r\n"
			}
			return out
		}

		var footer: Data {
			footerString.data(using: .utf8) ?? Data(footerString.utf8)
		}
		var footerString: String {
			"\r\n"
		}

		let name: String?
		let boundary: String
		let filename: String?
		let contentType: String?
		let content: Content?

		init(
			name: String?,
			boundary: String,
			filename: String? = nil,
			contentType: String? = nil,
			content: MultipartFormInputTempFile.Part.Content?) {
				self.name = name
				self.boundary = boundary
				self.filename = filename ?? content?.filename
				self.contentType = contentType ?? content?.filename.map { Self.getMimeType(forFileExtension: ($0 as NSString).pathExtension )}
				self.content = content
			}

		static let genericBinaryMimeType = "application/octet-stream"
		static func getMimeType(forFileExtension pathExt: String) -> String {
			if #available(OSX 11.0, iOS 14.0, tvOS 14.0, watchOS 14.0, *) {
				let type = UTType(filenameExtension: pathExt)
				return type?.preferredMIMEType ?? genericBinaryMimeType
			} else {
				guard
					let universalTypeIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExt as CFString, nil)?.takeRetainedValue(),
					let mimeType = UTTypeCopyPreferredTagWithClass(universalTypeIdentifier, kUTTagClassMIMEType)?.takeRetainedValue()
				else { return genericBinaryMimeType }

				return mimeType as String
			}
		}

		enum Content {
			case localURL(URL)
			case data(Data)

			var filename: String? {
				guard case .localURL(let url) = self else { return nil }
				return url.lastPathComponent
			}
		}
	}
}
