@_exported import NetworkHandler
import Foundation
import SwiftPizzaSnips
import Logging

extension URLSession: NetworkEngine {
	/// To properly support progress and other features fully, a specific, custom `URLSessionDelegate` is needed.
	/// This method eliminates the need for the user of this code to manage that themselves.
	///
	/// Additionally, during testing and troubleshooting, I had to constrain the URLSession delegate to a
	/// single operation queue for some reason. I believe I resolved the issue with correct thread safety in the
	/// delegate, but I don't want to remove the syncronous queue configuration until I know we are good to go.
	/// - Parameter configuration: URLSessionConfiguration - defaults to `.networkHandlerDefault`
	/// - Returns: a new `URLSession`
	public static func asEngine(
		withConfiguration configuration: URLSessionConfiguration = .networkHandlerDefault
	) -> URLSession {
		let delegate = UploadDellowFelegate()
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.name = "Dellow Felegate"
		return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
	}

	public func performNetworkTransfer(
		request: NetworkRequest,
		uploadProgressContinuation: UploadProgressStream.Continuation?,
		requestLogger: Logger?
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, responseBody: ResponseBodyStream) {
		guard
			let delegate = delegate as? UploadDellowFelegate
		else {
			throw .unspecifiedError(reason: """
				URLSession delegate must be an instance of `UploadDellowFelegate`. Create your URLSession with \
				`URLSession.asEngine()` to have this handled for you.
				""")
		}

		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)

		let (urlTask, payloadStream) = try getSessionTask(from: request)
		delegate.addTask(
			urlTask,
			withStream: payloadStream,
			progressContinuation: uploadProgressContinuation,
			bodyContinuation: bodyContinuation)
		if configuration.identifier == nil {
			urlTask.delegate = delegate
		}

		@Sendable
		func performCancellation() {
			urlTask.cancel()
			try? uploadProgressContinuation?.finish(throwing: CancellationError())
			try? bodyContinuation.finish(throwing: CancellationError())
		}

		let isUploadFinished = Sendify(false)
		uploadProgressContinuation?.onFinish { reason in
			isUploadFinished.value = true
			guard reason.finishedOrCancelledError != nil else { return }
			performCancellation()
		}

		bodyContinuation.onFinish { reason in
			guard reason.finishedOrCancelledError != nil else { return }
			performCancellation()
		}

		urlTask.resume()

		let response = try await NetworkError.captureAndConvert {
			while urlTask.response == nil {
				if let error = urlTask.error {
					throw error
				}
				let delayValue = isUploadFinished.value ? 20 : 100
				try await Task.sleep(for: .milliseconds(delayValue))
			}
			guard let response = urlTask.response else { fatalError("I just saw it right there!") }
			return EngineResponseHeader(from: response)
		}

		return (response, bodyStream)
	}

	private func getSessionTask(
		from request: NetworkRequest
	) throws(NetworkError) -> (task: URLSessionTask, inputStream: InputStream?) {
		switch request {
		case .upload(let uploadEngineRequest, let payload):
			let payloadStream: InputStream?
			switch payload {
			case .data(let data):
				payloadStream = InputStream(data: data)
			case .localFile(let localFile):
				guard
					let stream = InputStream(url: localFile)
				else { throw .unspecifiedError(reason: "Creating a stream from the referenced local file failed. \(localFile)") }
				payloadStream = stream
			case .inputStream(let stream):
				payloadStream = stream
			}
			let urlRequest = uploadEngineRequest.urlRequest

			let task = uploadTask(withStreamedRequest: urlRequest)
			return (task, payloadStream)
		case .general(let generalEngineRequest):
			let task = dataTask(with: generalEngineRequest.urlRequest)
			return (task, nil)
		}
	}

	public func shutdown() {
		finishTasksAndInvalidate()
	}

	// hard coded into NetworkError - no need to implement here
	public static func isCancellationError(_ error: any Error) -> Bool { false }

	// hard coded into NetworkError - no need to implement here
	public static func isTimeoutError(_ error: any Error) -> Bool { false }
}
