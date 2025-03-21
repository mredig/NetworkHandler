import Foundation
import Logging

/// A class delightfully engineered to seamlessly concatenate multiple `InputStream` instances.
///
/// Think of it as a marvelous utilitarian tool akin to the Pan Galactic Gargle Blaster.
/// It elegantly takes multiple `InputStream`s—each potentially brimming with untold data—
/// and melds them into a single cohesive stream. Whether used for combining files, network
/// responses, or other miscellany of data, its sole mission is to deliver your concatenated
/// content with the smooth precision of a hyperspace bypass.
///
/// Overrides the standard `InputStream` methods for proper functionality, sprinkling in
/// just the right amount of additional logic to achieve its heroic task of unification.
public class ConcatenatedInputStream: InputStream {

	public private(set) var streams: [InputStream] = []

	private var streamIndex = 0

	public override var hasBytesAvailable: Bool {
		(try? getCurrentStream().hasBytesAvailable) ?? false
	}

	private var _streamStatus: Stream.Status = .notOpen
	public override var streamStatus: Stream.Status { _streamStatus }

	public init(streams: [InputStream], logger: Logger? = nil) throws {
		super.init(data: Data())

		try streams.forEach {
			try addStream($0)
		}
	}

	public var logger: Logger?

	public init(logger: Logger? = nil) {
		super.init(data: Data())
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

	public func addStream(_ stream: InputStream) throws {
		guard _streamStatus == .notOpen else { throw StreamConcatError.cannotAddStreamsOnceOpen }
		switch stream.streamStatus {
		case .open:
			logger?.warning("""
				Warning: stream already open after adding to concatenation. When reading, it will continue where \
				it left off, if already read.
				""")
		case .notOpen:
			break
		default:
			throw StreamConcatError.mustStartInNotOpenState
		}
		streams.append(stream)
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
				logger?.error("Error getting current stream: \(error)")
			}
		}
		return count
	}

	private func read(
		stream: InputStream,
		into pointer: UnsafeMutablePointer<UInt8>,
		writingIntoPointerAt startOffset: Int,
		maxLength: Int
	) -> Int {
		let pointerWithOffset = pointer.advanced(by: startOffset)
		return stream.read(pointerWithOffset, maxLength: maxLength)
	}

	private func getCurrentStream() throws -> InputStream {
		guard streamIndex < streams.count else { throw StreamConcatError.atEndOfStreams }
		let stream = streams[streamIndex]
		switch stream.streamStatus {
		case .open:
			if stream.hasBytesAvailable {
				return stream
			} else {
				stream.close()
				return try getCurrentStream()
			}
		case .notOpen:
			stream.open()
			return try getCurrentStream()
		case .atEnd:
			stream.close()
			streamIndex += 1
			return try getCurrentStream()
		case .error:
			throw stream.streamError ?? StreamConcatError.unknownError
		case .closed:
			if streamIndex >= streams.count {
				throw StreamConcatError.atEndOfStreams
			} else {
				streamIndex += 1
				return try getCurrentStream()
			}
		default:
			logger?.error("Unexpected status: \(stream.streamStatus)")
			throw StreamConcatError.unexpectedStatus(stream.streamStatus)
		}
	}

	public override func getBuffer(
		_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
		length len: UnsafeMutablePointer<Int>
	) -> Bool { false }

	public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
	#if canImport(FoundationNetworking)
	public override func property(forKey key: Stream.PropertyKey) -> AnyObject? { nil }
	public override func setProperty(_ property: AnyObject?, forKey key: Stream.PropertyKey) -> Bool { false }
	#else
	public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
	public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
	#endif

	public enum StreamConcatError: Error {
		case atEndOfStreams
		case unexpectedStatus(Stream.Status)
		case mustStartInNotOpenState
		case cannotAddStreamsOnceOpen
		case unknownError
	}
}
