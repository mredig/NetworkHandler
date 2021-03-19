import Foundation

public class MultipartFormInputStream: InputStream {
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
