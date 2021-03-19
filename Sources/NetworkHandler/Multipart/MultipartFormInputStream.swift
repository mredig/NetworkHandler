import Foundation

public class MultipartInputStream: InputStream {
	public let boundary: String
	public private(set) var length: Int
	public private(set) var delivered: Int = 0

	public var multipartContentTypeHeaderValue: HTTPHeaderValue {
		"multipart/form-data; boundary=\(boundary)"
	}

	private var parts: [Part] = []
	private var currentPart = 0
	private let footer: Data
	private lazy var footerStream: InputStream = {
		let stream = InputStream(data: footer)
		stream.open()
		return stream
	}()
	private var _streamStatus: Stream.Status = .notOpen
	public override var streamStatus: Stream.Status {
		_streamStatus
	}

	public override var hasBytesAvailable: Bool {
		parts.last?.hasBytesAvailable ?? false
	}

	private weak var _delegate: StreamDelegate?
	public override var delegate: StreamDelegate? {
		get { _delegate }
		set { _delegate = newValue }
	}

	public init(boundary: String = UUID().uuidString) {
		self.boundary = "Boundary-\(boundary)"
		self.length = 0
		let footer = "--\(boundary)--\r\n"
		self.footer = footer.data(using: .utf8) ?? Data(footer.utf8)
		super.init(data: Data())
	}

	public func addPart(named name: String, string: String) {
		let part = Part(withName: name, boundary: boundary, string: string)
		parts.append(part)
		updateLength()
	}

	public func addPart(named name: String, data: Data, filename: String? = nil, contentType: String = "application/octet-stream") {
		let part = Part(withName: name, boundary: boundary, data: data, contentType: contentType, filename: filename)
		parts.append(part)
		updateLength()
	}

	public func addPart(named name: String, fileURL: URL, filename: String? = nil, contentType: String) {
		guard let part = Part(withName: name, boundary: boundary, filename: filename, fileURL: fileURL, contentType: contentType) else {
			print("Failure to add part with file. Probably can't read the file.")
			return
		}
		parts.append(part)
		updateLength()
	}

	public func addPart(named name: String, stream: InputStream, streamFilename: String, streamLength: Int) {
		let part = Part(withName: name, boundary: boundary, stream: stream, streamFilename: streamFilename, streamLength: streamLength)
		parts.append(part)
		updateLength()
	}

	private func updateLength() {
		length = footer.count + parts.reduce(0, { $0 + $1.length })
	}

	public override func open() {
		_streamStatus = .open
		parts.append(.init(footerStreamWithBoundary: boundary))
	}

	public override func close() {
		_streamStatus = .closed
	}

	public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
		_streamStatus = .reading
		var statusOnExit: Stream.Status = .open
		defer { _streamStatus = statusOnExit }

		var count = 0
		while count < len {
			do {
				let part = try getCurrentPart()
				count += read(part: part, into: buffer, writingIntoPointerAt: count, maxLength: len - count)
			} catch Part.PartError.atEndOfStreams {
				statusOnExit = .atEnd
				return count
			} catch {
				statusOnExit = .error
				print("Error getting current stream: \(error)")
			}
		}

		return count
	}

	private func read(part: Part, into pointer: UnsafeMutablePointer<UInt8>, writingIntoPointerAt startOffset: Int, maxLength: Int) -> Int {
		let pointerWithOffset = pointer.advanced(by: startOffset)
		return part.read(pointerWithOffset, maxLength: maxLength)
	}

	private func getCurrentPart() throws -> Part {
		guard currentPart < parts.count else { throw Part.PartError.atEndOfStreams }
		let part = parts[currentPart]
		guard part.hasBytesAvailable else {
			currentPart += 1
			return try getCurrentPart()
		}
		return part
	}

	public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
		false
	}

	public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
	public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
}


extension MultipartInputStream {
	class Part {
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
			let contentType = contentType!

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
			let contentType = "application/octet-strem"
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
