import Foundation

public protocol RetryableStream: InputStream {
	func copyWithRestart() throws(NetworkError) -> Self
}

public protocol KnownLengthStream: InputStream {
	var totalStreamBytes: Int? { get }
}
