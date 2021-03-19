import Foundation

public class MultipartFormInputStream: ConcatenatedInputStream {
	public let boundary: String

	public var multipartContentTypeHeaderValue: HTTPHeaderValue {
		"multipart/form-data; boundary=\(boundary)"
	}

	private weak var _delegate: StreamDelegate?
	public override var delegate: StreamDelegate? {
		get { _delegate }
		set { _delegate = newValue }
	}

	public init(boundary: String = UUID().uuidString) {
		self.boundary = "Boundary-\(boundary)"
		super.init()
	}

	public func addPart(named name: String, string: String) {
		let part = Part(withName: name, boundary: boundary, string: string)
		// there is no way this should be able to fail
		try! addStream(part)
	}

	public func addPart(named name: String, data: Data, filename: String? = nil, contentType: String = "application/octet-stream") {
		let part = Part(withName: name, boundary: boundary, data: data, contentType: contentType, filename: filename)
		// there is no way this should be able to fail
		try! addStream(part)
	}

	public func addPart(named name: String, fileURL: URL, filename: String? = nil, contentType: String) throws {
		let part = try Part(withName: name, boundary: boundary, filename: filename, fileURL: fileURL, contentType: contentType)
		try addStream(part)
	}

	public func addPart(named name: String, stream: InputStream, streamFilename: String, streamLength: Int) throws {
		let part = try Part(withName: name, boundary: boundary, stream: stream, streamFilename: streamFilename, streamLength: streamLength)
		try addStream(part)
	}

	public override func open() {
		// there is no way this should be able to fail
		try! addStream(Part(footerStreamWithBoundary: boundary))
		super.open()
	}

	public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
		false
	}

	public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
	public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
}
