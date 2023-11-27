import Foundation

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
				self.contentType = contentType ?? content?
					.filename
					.map { MultipartFormInputStream.getMimeType(forFileExtension: ($0 as NSString).pathExtension ) }
				self.content = content
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
