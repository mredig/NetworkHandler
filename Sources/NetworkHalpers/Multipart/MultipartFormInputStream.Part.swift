import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

extension MultipartFormInputStream {
	static let genericBinaryMimeType = "application/octet-stream"
	static func getMimeType(forFileExtension pathExt: String) -> String {
		#if canImport(UniformTypeIdentifiers)
		if #available(OSX 11.0, iOS 14.0, tvOS 14.0, watchOS 14.0, *) {
			let type = UTType(filenameExtension: pathExt)
			return type?.preferredMIMEType ?? genericBinaryMimeType
		} else {
			guard
				let universalTypeIdentifier = UTTypeCreatePreferredIdentifierForTag(
					kUTTagClassFilenameExtension,
					pathExt as CFString,
					nil)?
					.takeRetainedValue(),
				let mimeType = UTTypeCopyPreferredTagWithClass(
					universalTypeIdentifier,
					kUTTagClassMIMEType)?
					.takeRetainedValue()
			else { return genericBinaryMimeType }

			return mimeType as String
		}
		#else
		genericBinaryMimeType
		#endif
	}

	class Part: ConcatenatedInputStream {
		let copyGenerator: () -> Part

		let headers: Data
		let body: InputStream
		var bodyLength: Int
		var headersLength: Int { headers.count }
		var length: Int { headersLength + bodyLength + 2 }

		private lazy var headerStream: InputStream = {
			let stream = InputStream(data: headers)
			return stream
		}()

		private let footerStream: InputStream = {
			let stream = InputStream(data: "\r\n".data(using: .utf8)!)
			return stream
		}()

		init(withName name: String, boundary: String, string: String) {
			let headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			let strData = string.data(using: .utf8) ?? Data(string.utf8)
			self.body = InputStream(data: strData)
			self.bodyLength = strData.count
			self.copyGenerator = {
				Part(withName: name, boundary: boundary, string: string)
			}

			super.init()
		}

		init(withName name: String, boundary: String, data: Data, contentType: String, filename: String? = nil) {
			let headerStr: String
			if let filename = filename {
				headerStr = """
				--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-\
				Type: \(contentType)\r\n\r\n
				"""
			} else {
				headerStr = """
				--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\nContent-Type: \(contentType)\r\n\r\n
				"""
			}
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			self.body = InputStream(data: data)
			self.bodyLength = data.count
			self.copyGenerator = {
				Part(withName: name, boundary: boundary, data: data, contentType: contentType, filename: filename)
			}
			super.init()
		}

		init(
			withName name: String,
			boundary: String,
			filename: String? = nil,
			fileURL: URL,
			contentType: String? = nil
		) throws {
			let contentType = contentType ?? MultipartFormInputStream.getMimeType(forFileExtension: fileURL.pathExtension)

			let headerStr = """
				--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; \
				filename=\"\(filename ?? fileURL.lastPathComponent)\"\r\nContent-Type: \(contentType)\r\n\r\n
				"""
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			guard
				let fileStream = InputStream(url: fileURL),
				let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
				let fileSize = attributes[.size] as? Int
			else { throw PartError.fileAttributesInaccessible }
			self.body = fileStream
			self.bodyLength = fileSize
			self.copyGenerator = {
				// swiftlint:disable:next force_try
				try! Part(withName: name, boundary: boundary, filename: filename, fileURL: fileURL, contentType: contentType)
			}
			super.init()
		}

		init(footerStreamWithBoundary boundary: String) {
			let headerStr = "--"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			let bodyStr = "\(boundary)--"
			let body = bodyStr.data(using: .utf8) ?? Data(bodyStr.utf8)
			self.body = InputStream(data: body)
			self.bodyLength = body.count
			self.copyGenerator = {
				Part(footerStreamWithBoundary: boundary)
			}
			super.init()
		}

		override func close() {
			super.close()
		}

		override func open() {
			do {
				try addStream(headerStream)
				try addStream(body)
				try addStream(footerStream)
			} catch {
				log.error("Error concatenating streams: \(error)")
			}
			super.open()
		}

		enum PartError: Error {
			case fileAttributesInaccessible
		}
	}
}

extension MultipartFormInputStream.Part: NSCopying {
	func copy(with zone: NSZone? = nil) -> Any {
		copyGenerator()
	}
}
