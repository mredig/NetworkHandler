import Foundation

public class ConcatenatedInputStream: InputStream {

	public private(set) var streams: [InputStream] = []

	private var streamIndex = 0

	public override var hasBytesAvailable: Bool {
		streams.last?.hasBytesAvailable ?? false
	}

	private var _streamStatus: Stream.Status = .notOpen
	public override var streamStatus: Stream.Status { _streamStatus }

	public convenience init(streams: [InputStream]) throws {
		self.init()
		self.streams = streams
		try streams.forEach {
			switch $0.streamStatus {
			case .open:
				print("Warning: stream already open after adding to concatenation. When reading, it will continue where it left off, if already read.")
				return
			case .notOpen:
				$0.open()
			default:
				throw StreamConcatError.mustStartInNotOpenState
			}
		}
	}

	public override func open() {
		_streamStatus = .open
	}

	public override func close() {
		_streamStatus = .closed
	}

	private weak var _delegate: StreamDelegate?
	public override var delegate: StreamDelegate? {
		get { _delegate }
		set { _delegate = newValue }
	}

	public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
		_streamStatus = .reading
		var statusOnExit: Stream.Status = .open
		defer { _streamStatus = statusOnExit }

		var count = 0
		while count < len {
			do {
				let stream = try getCurrentStream()
				count += read(stream: stream, into: buffer, writingIntoPointerAt: count, maxLength: len - count)
			} catch StreamConcatError.atEndOfStreams {
				statusOnExit = .atEnd
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
		guard streamIndex < streams.count else { throw StreamConcatError.atEndOfStreams }
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
			throw StreamConcatError.unexpectedStatus(stream.streamStatus)
		}
	}

	public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool { false }

	public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
	public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }

	public enum StreamConcatError: Error {
		case atEndOfStreams
		case unexpectedStatus(Stream.Status)
		case mustStartInNotOpenState
	}
}
