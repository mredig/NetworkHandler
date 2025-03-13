import Foundation
import SwiftPizzaSnips
import Logging

public typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
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

	/// This is the method that NetworkHandler will likely call the majority of the time. It will be used both for
	/// small uploads and any sized downloads. Fairly straightforward to implement.
	///
	/// 1. Convert `request` to the native engine request type
	/// 2. Send the request to the server.
	/// 3. Upon receiving the server response, convert it to `EngineResponseHeader`
	/// 4. Create a `ResponseBodyStream` and initiate forwarding the stream of data from the engine that will outlive
	/// the scope of this method until the incoming data is completed or the transfer is cancelled.
	/// 5. Return the tuple
	///
	/// During these steps, if you encounter any errors or need to forward any from the engine,
	/// wrap them in `NetworkError.captureAndConvert()`
	///
	/// Througout this process, log any relevant messages in `requestLogger`
	/// - Parameters:
	///   - request: The request
	///   - requestLogger: logger to use
	func fetchNetworkData(
		from request: GeneralEngineRequest,
		requestLogger: Logger?
	) async throws(NetworkError) -> (EngineResponseHeader, ResponseBodyStream)

	/// This method is only called when there's more significant data to be sent to the server. I think I'm going to
	/// refactor it, so I will write docs for it then, but if I forget, feel free to publicly shame me (or if you
	/// think you got it, open a PR. AND publicly shame me).
	///
	/// - Parameters:
	///   - request: The request
	///   - payload: payload to upload - could be `Data`, a file `URL`, or an `InputStream`
	///   - requestLogger: logger to use
	func uploadNetworkData(
		request: inout UploadEngineRequest,
		with payload: UploadFile,
		uploadProgressContinuation: UploadProgressStream.Continuation,
		requestLogger: Logger?
	) async throws(NetworkError) -> (
		responseTask: ETask<EngineResponseHeader, NetworkError>,
		responseBody: ResponseBodyStream)
	
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
