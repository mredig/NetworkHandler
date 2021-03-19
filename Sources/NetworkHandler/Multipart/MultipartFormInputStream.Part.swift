import Foundation
import CoreServices
import UniformTypeIdentifiers

extension MultipartFormInputStream {
	class Part: ConcatenatedInputStream {
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

			super.init()
		}

		init(withName name: String, boundary: String, data: Data, contentType: String, filename: String? = nil) {
			let headerStr: String
			if let filename = filename {
				headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(contentType)\r\n\r\n"
			} else {
				headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\nContent-Type: \(contentType)\r\n\r\n"
			}
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			self.body = InputStream(data: data)
			self.bodyLength = data.count

			super.init()
		}

		init(withName name: String, boundary: String, filename: String? = nil, fileURL: URL, contentType: String? = nil) throws {
			let contentType = contentType ?? Self.getMimeType(forFileExtension: fileURL.pathExtension)

			let headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename ?? fileURL.lastPathComponent)\"\r\nContent-Type: \(contentType)\r\n\r\n"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			guard
				let fileStream = InputStream(url: fileURL),
				let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
				let fileSize = attributes[.size] as? Int
			else { throw PartError.fileAttributesInaccessible }
			self.body = fileStream
			self.bodyLength = fileSize

			super.init()
		}

		init(withName name: String, boundary: String, stream: InputStream, streamFilename: String, streamLength: Int) throws {
			switch stream.streamStatus {
			case .notOpen, .open:
				break
			default:
				throw StreamConcatError.mustStartInNotOpenState
			}
			let contentType = Self.genericBinaryMimeType
			let headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(streamFilename)\"\r\nContent-Type: \(contentType)\r\n\r\n"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			self.body = stream
			self.bodyLength = streamLength

			super.init()
		}

		init(footerStreamWithBoundary boundary: String) {
			let headerStr = "--"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			let bodyStr = "\(boundary)--"
			let body = bodyStr.data(using: .utf8) ?? Data(bodyStr.utf8)
			self.body = InputStream(data: body)
			self.bodyLength = body.count

			super.init()
		}

		override func close() {
			super.close()
		}

		override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
			super.read(buffer, maxLength: len)
		}

		override func open() {
			do {
				try addStream(headerStream)
				try addStream(body)
				try addStream(footerStream)
			} catch {
				print("Error concatenating streams: \(error)")
			}
			super.open()
		}

		enum PartError: Error {
			case fileAttributesInaccessible
		}
	}
}
