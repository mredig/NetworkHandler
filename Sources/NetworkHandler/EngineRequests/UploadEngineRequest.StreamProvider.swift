import NetworkHalpers
import Foundation

extension UploadEngineRequest {
	public final class StreamProvider: InputStream, @unchecked Sendable {
		public typealias StreamBlock = @Sendable (_ startOffset: Int, _ requestedByteCount: Int) throws -> Data?
		public let block: StreamBlock

		public let hasDataAvailableBlock: @Sendable (_ startOffset: Int) -> Bool

		public let totalStreamBytes: Int?
		public var progress: Double? {
			lock.withLock {
				guard let totalStreamBytes else { return nil }
				return Double(currentOffset) / Double(totalStreamBytes)
			}
		}

		private let lock = NSLock()

		public override var hasBytesAvailable: Bool { lock.withLock { hasDataAvailableBlock(currentOffset) } }

		nonisolated(unsafe)
		private var _streamStatus: Stream.Status = .notOpen
		public override var streamStatus: Stream.Status { lock.withLock { _streamStatus } }

		private var _streamError: (any Error)?
		public override var streamError: (any Error)? { lock.withLock { _streamError } }

		private var currentOffset = 0

		private weak var _delegate: StreamDelegate?
		public override var delegate: StreamDelegate? {
			get { _delegate ?? (self as? StreamDelegate) }
			set { _delegate = newValue }
		}

		public init(
			block: @escaping StreamBlock,
			hasDataAvailableBlock: @escaping @Sendable (_ startOffset: Int) -> Bool,
			totalStreamBytes: Int? = nil
		) {
			self.block = block
			self.hasDataAvailableBlock = hasDataAvailableBlock
			self.totalStreamBytes = totalStreamBytes

			super.init(data: Data())
		}

		public override func open() {
			lock.withLock { _streamStatus = .open }
		}

		public override func close() {
			lock.withLock { _streamStatus = .closed }
		}

		public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
			lock.lock()
			defer { lock.unlock() }
			_streamStatus = .reading
			var statusOnExit: Stream.Status = .open
			defer { _streamStatus = statusOnExit }

			do {
				guard
					let chunk = try block(currentOffset, len),
					chunk.isEmpty == false
				else {
					statusOnExit = .atEnd
					return 0
				}

				currentOffset += chunk.count

				guard
					chunk.count <= len
				else { throw StreamError.streamProvidedTooMuchData }

				try chunk.withUnsafeBytes({ (chunkBuffer: UnsafeRawBufferPointer) in
					try chunkBuffer.withMemoryRebound(to: UInt8.self) { chunkPointer in
						guard let address = chunkPointer.baseAddress else { throw StreamError.cannotFindMemoryAddress }
						buffer.initialize(from: address, count: chunk.count)
					}
				})

				if hasDataAvailableBlock(currentOffset) == false {
					statusOnExit = .atEnd
				}

				return chunk.count
			} catch {
				statusOnExit = .error
				self._streamError = error
				return -1
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

		public static func == (lhs: StreamProvider, rhs: StreamProvider) -> Bool {
			lhs === rhs
		}

		public enum StreamError: Error {
			case cannotFindMemoryAddress
			case streamProvidedTooMuchData
		}
	}
}
