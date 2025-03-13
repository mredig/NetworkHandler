import Foundation

/// A protocol that defines a stream which can be retried after failure. Conformance to this protocol enables
/// retry mechanisms for streams, a functionality often precluded because standard `InputStream` implementations
/// proceed from their last position.
/// 
/// This is particularly useful in scenarios such as HTTP request bodies, where a stream's ability to restart
/// from the beginning significantly facilitates automatic network error recovery.
/// 
/// - Important: Ensure conforming types properly implement `copyWithRestart()` to return a stream starting
/// fresh from its initial position of data.
public protocol RetryableStream: InputStream {
	/// Creates a duplicate of the current stream that can start from the beginning.
	func copyWithRestart() throws(NetworkError) -> Self
}

/// A protocol that defines a stream with a known total length of bytes, important in scenarios where the content
/// length of a stream needs to be explicitly stated, such as HTTP uploads.
///
/// By conforming to this protocol, stream implementations can clearly communicate their total byte count, allowing
/// for proper configuration of `Content-Length` headers and precise progress tracking during transfers.
public protocol KnownLengthStream: InputStream {
	/// An optional `Int` representing the total size of the stream's data in bytes. Returns `nil` for indeterminate lengths.
	var totalStreamBytes: Int? { get }
}
