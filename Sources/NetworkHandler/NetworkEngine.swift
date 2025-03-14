import Foundation
import SwiftPizzaSnips
import Logging

/// Convenience type for forwarding the content of a response body.
public typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>

/// Convenience type for communicating upload progress. The yielded value should be the total number of
/// bytes sent in this request.
public typealias UploadProgressStream = AsyncCancellableThrowingStream<Int64, Error>

/// The magic that makes everything work!
///
/// Default implementations are provided for `URLSession` and `AsyncHTTPClient`.
///
/// Conforming to this protocol with another engine automatically gets you simple streaming, automatic retry on
/// errors, polling functionality (beta), tightly controlled caching functionality, conveniences for encoding and
/// decoding data for sending and receiving from remote servers, and more! With a little additional elbow grease,
/// you can also get simple token based cancellation and activity based timeouts.
public protocol NetworkEngine: Sendable, Withable {

	/// Conforming to NetworkEngine primarily revolves around this method. The primary requirements are as follows:
	///
	/// 1. Convert `request` to the native engine request type
	/// 2. Send the request to the server. If this is an upload, make sure to communicate
	/// upload progress with `uploadProgressContinuation`
	/// 3. Upon receiving the server response, convert it to `EngineResponseHeader`
	/// 4. Create a `ResponseBodyStream` and initiate forwarding the stream of data from the engine that will outlive
	/// the scope of this method until the incoming data is completed or the transfer is cancelled.
	/// 5. Return the tuple
	/// 
	/// During these steps, if you encounter any errors or need to forward any from the engine,
	/// wrap them in `NetworkError.captureAndConvert()`
	///
	/// Ensure you have robost cancellation support through your implementation. If activity based timeout isn't native
	/// to your engine, refer to the `AsyncHTTPClient` engine conformance for how to include that with your
	/// own engine with a simple debouncer on activity.
	///
	/// Througout this process, log any relevant messages in `requestLogger`
	/// - Parameters:
	///   - request: The request
	///   - uploadProgressContinuation: Stream Continuation to foward upload progress updates to NetworkHandler.
	///   Required to use when performing an upload request. Nice to have when performing a general request.
	///   - requestLogger: logger to use
	func performNetworkTransfer(
		request: NetworkRequest,
		uploadProgressContinuation: UploadProgressStream.Continuation?,
		requestLogger: Logger?
	) async throws(NetworkError) -> (responseTask: EngineResponseHeader, responseBody: ResponseBodyStream)

	/// Since networking is fraught with potential errors, `NetworkHandler` tries to normalize them into
	/// `NetworkError` using `NetworkError.captureAndConvert()`.  When `NetworkError.captureAndConvert`
	/// encounters an error it doesn't understand, it queries this method to see if it counts as a cancellation
	/// error. Consequently, you'll want to create an implementation that analyzes the error for known
	/// cancellation errors from your engine and return `true` when that's the case.
	/// - Parameter error: The error `NetworkError` is unsure about
	/// - Returns: Boolean indicating whether the error indicates a cancellation
	static func isCancellationError(_ error: any Error) -> Bool
	/// Since networking is fraught with potential errors, `NetworkHandler` tries to normalize them into
	/// `NetworkError` using `NetworkError.captureAndConvert()`.  When `NetworkError.captureAndConvert`
	/// encounters an error it doesn't understand, it queries this method to see if it counts as a timeout
	/// error. Consequently, you'll want to create an implementation that analyzes the error for known
	/// timeout indication errors from your engine and return `true` when that's the case.
	/// - Parameter error: The error `NetworkError` is unsure about
	/// - Returns: Boolean indicating whether the error indicates a timeout
	static func isTimeoutError(_ error: any Error) -> Bool

	/// This method is called when `NetworkHandler` is being released from memory. This allows your engine to perform
	/// any cleanup and shutdown necessary to avoid leaking memory. If that's unecessary for your particular engine, an
	/// empty implementation is accepted.
	func shutdown()
}
