import Foundation

public protocol RetryableStream: InputStream {
	func copyWithRestart() throws(NetworkError) -> Self
}
