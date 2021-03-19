import Foundation
import CoreServices
import UniformTypeIdentifiers

extension MultipartFormInputStream {
	class Part {
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

		init(withName name: String, boundary: String, string: String) {
			let headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			let strData = string.data(using: .utf8) ?? Data(string.utf8)
			self.body = InputStream(data: strData)
			self.bodyLength = strData.count

			commonInit()
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

			commonInit()
		}

		init?(withName name: String, boundary: String, filename: String? = nil, fileURL: URL, contentType: String? = nil) {
			let contentType = contentType ?? Self.getMimeType(forFileExtension: fileURL.pathExtension)

			let headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename ?? fileURL.lastPathComponent)\"\r\nContent-Type: \(contentType)\r\n\r\n"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			guard
				let fileStream = InputStream(url: fileURL),
				let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
				let fileSize = attributes[.size] as? Int
			else { return nil }
			self.body = fileStream
			self.bodyLength = fileSize

			commonInit()
		}

		init(withName name: String, boundary: String, stream: InputStream, streamFilename: String, streamLength: Int) {
			let contentType = Self.genericBinaryMimeType
			let headerStr = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(streamFilename)\"\r\nContent-Type: \(contentType)\r\n\r\n"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			self.body = stream
			self.bodyLength = streamLength

			commonInit()
		}

		init(footerStreamWithBoundary boundary: String) {
			let headerStr = "--"
			self.headers = headerStr.data(using: .utf8) ?? Data(headerStr.utf8)
			let bodyStr = "\(boundary)--"
			let body = bodyStr.data(using: .utf8) ?? Data(bodyStr.utf8)
			self.body = InputStream(data: body)
			self.bodyLength = body.count
		}

		private func commonInit() {
			body.open()
		}

		private lazy var headerStream: InputStream = {
			let stream = InputStream(data: headers)
			stream.open()
			return stream
		}()

		private let footerStream: InputStream = {
			let stream = InputStream(data: "\r\n".data(using: .utf8)!)
			stream.open()
			return stream
		}()
		private lazy var streams = [
			headerStream,
			body,
			footerStream
		]
		private var streamIndex: Int = 0
		var hasBytesAvailable: Bool {
			streams.last?.hasBytesAvailable ?? false
		}

		func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
			var count = 0
			while count < len {
				do {
					let stream = try getCurrentStream()
					count += read(stream: stream, into: buffer, writingIntoPointerAt: count, maxLength: len - count)
				} catch PartError.atEndOfStreams {
					return count
				} catch {
					print("Error getting current stream: \(error)")
				}
			}
			return count
		}

		private func read(stream: InputStream, into pointer: UnsafeMutablePointer<UInt8>, writingIntoPointerAt startOffset: Int, maxLength: Int) -> Int {
			let pointerWithOffset = pointer.advanced(by: startOffset)
			return stream.read(pointerWithOffset, maxLength: maxLength)
		}

		private func getCurrentStream() throws -> InputStream {
			guard streamIndex < streams.count else { throw PartError.atEndOfStreams }
			let stream = streams[streamIndex]
			switch stream.streamStatus {
			case .open:
				return stream
			case .notOpen:
				stream.open()
				return try getCurrentStream()
			case .atEnd:
				stream.close()
				streamIndex += 1
				return try getCurrentStream()
			case .error:
				throw stream.streamError!
			default:
				print("Unexpected status: \(stream.streamStatus)")
				throw PartError.unexpectedStatus(stream.streamStatus)
			}
		}

		enum PartError: Error {
			case atEndOfStreams
			case unexpectedStatus(Stream.Status)
		}
	}
}
