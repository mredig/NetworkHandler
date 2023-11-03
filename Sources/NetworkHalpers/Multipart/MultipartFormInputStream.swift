import Foundation

/**
Use this to generate a stream to upload multipart form data. This can be very efficient as it generates meta data on
the fly and streams data from existing sources (both Data in memory and bytes from disk) instead of copying any data
elsewhere. However, it does NOT allow for accurate progress when uploading and ultimately may result in highly
inaccurate progress reports. Because of this, I'm not sure if it's worth holding onto this class and am considering
deprecating it.
*/
public class MultipartFormInputStream: ConcatenatedInputStream {
	public let boundary: String
	private let originalBoundary: String

	private var addedFooter = false

	/// intended to be an approximation, not exact. Will not include footer if has not been added yet.
	public var totalSize: Int {
		streams.reduce(0) { $0 + (($1 as? Part)?.length ?? 0) }
	}

	public var multipartContentTypeHeaderValue: HTTPHeaderValue {
		"multipart/form-data; boundary=\(boundary)"
	}

	private weak var _delegate: StreamDelegate?
	public override var delegate: StreamDelegate? {
		get { _delegate }
		set { _delegate = newValue }
	}

	public init(boundary: String = UUID().uuidString) {
		self.originalBoundary = boundary
		self.boundary = "Boundary-\(boundary)"
		super.init()
	}

	public func addPart(named name: String, string: String) {
		let part = Part(withName: name, boundary: boundary, string: string)
		// there is no way this should be able to fail
		try! addStream(part) // swiftlint:disable:this force_try
	}

	public func addPart(
		named name: String,
		data: Data,
		filename: String? = nil,
		contentType: String = "application/octet-stream"
	) {
		let part = Part(withName: name, boundary: boundary, data: data, contentType: contentType, filename: filename)
		// there is no way this should be able to fail
		try! addStream(part) // swiftlint:disable:this force_try
	}

	public func addPart(
		named name: String,
		fileURL: URL,
		filename: String? = nil,
		contentType: String
	) throws {
		let part = try Part(
			withName: name,
			boundary: boundary,
			filename: filename,
			fileURL: fileURL,
			contentType: contentType)
		try addStream(part)
	}

	public override func open() {
		if addedFooter == false {
			// there is no way this should be able to fail
			try! addStream(Part(footerStreamWithBoundary: boundary)) // swiftlint:disable:this force_try
			addedFooter = true
		}
		super.open()
	}

	public override func getBuffer(
		_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
		length len: UnsafeMutablePointer<Int>
	) -> Bool { false }

	public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
	public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }

	public override func addStream(_ stream: InputStream) throws {
		guard type(of: stream) == Part.self else { throw MultipartError.streamNotPart }
		try super.addStream(stream)
	}

	enum MultipartError: Error {
		case streamNotPart
	}
}

extension MultipartFormInputStream: NSCopying {
	public func copy(with zone: NSZone? = nil) -> Any {
		safeCopy()
	}

	public func safeCopy() -> MultipartFormInputStream {
		let newCopy = MultipartFormInputStream(boundary: originalBoundary)

		streams.forEach {
			guard let streamCopy = $0.copy() as? Part else { fatalError("Can't copy stream") }
			try! newCopy.addStream(streamCopy) // swiftlint:disable:this force_try
		}

		newCopy.addedFooter = addedFooter

		return newCopy
	}
}
