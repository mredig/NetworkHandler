@_exported import NetworkHandler
import Foundation
import SwiftPizzaSnips
import Logging

extension URLSession: NetworkEngine {
	/// During testing and troubleshooting, I had to constrain the URLSession delegate to a single operation queue
	/// for some reason. I believe I resolved the issue with correct thread safety in the delegate, but I don't want to
	/// remove this standardized configuration until I know we are good to go.
	/// - Parameter configuration: URLSessionConfiguration - defaults to `.networkHandlerDefault`
	/// - Returns: a new `URLSession`
	public static func asEngine(withConfiguration configuration: URLSessionConfiguration = .networkHandlerDefault) -> URLSession {
		let delegate = UploadDellowFelegate()
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.name = "Dellow Felegate"
		return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
	}

	public func fetchNetworkData(
		from request: DownloadEngineRequest,
		requestLogger: Logger?
	) async throws(NetworkError) -> (EngineResponseHeader, ResponseBodyStream) {
		let urlRequest = request.urlRequest
		let (dlBytes, response) = try await NetworkError.captureAndConvert { try await bytes(for: urlRequest) }

		let engResponse = EngineResponseHeader(from: response as! HTTPURLResponse)
		let (stream, continuation) = ResponseBodyStream.makeStream(errorOnCancellation: CancellationError())

		let byteGobbler = Task {
			do {
				var buffer: [UInt8] = []
				buffer.reserveCapacity(1024)
				for try await byte in dlBytes {
					buffer.append(byte)

					guard buffer.count == 1024 else { continue }
					try continuation.yield(buffer)
					buffer.removeAll(keepingCapacity: true)
				}
				if buffer.isOccupied {
					try continuation.yield(buffer)
				}
				try continuation.finish()
			} catch {
				try continuation.finish(throwing: error)
			}
		}

		continuation.onFinish { reason in
			let proceed: Bool
			switch reason {
			case .cancelled: proceed = true
			case .finished(let error):
				proceed = error != nil
			}
			guard proceed else { return }
			dlBytes.task.cancel()
			byteGobbler.cancel()
		}

		return (engResponse, stream)
	}

	public func uploadNetworkData(
		request: inout UploadEngineRequest,
		with payload: UploadFile,
		requestLogger: Logger?
	) async throws(NetworkError) -> (
		uploadProgress: UploadProgressStream,
		responseTask: ETask<EngineResponseHeader, NetworkError>,
		responseBody: ResponseBodyStream
	) {

		let (progStream, progContinuation) = UploadProgressStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)
		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)

		let delegate = delegate as! UploadDellowFelegate

		let payloadStream: InputStream
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
		let urlRequest = request.urlRequest

		let urlTask = uploadTask(withStreamedRequest: urlRequest)

		delegate.addTask(
			urlTask,
			withStream: payloadStream,
			progressContinuation: progContinuation,
			bodyContinuation: bodyContinuation)
		if configuration.identifier == nil {
			urlTask.delegate = delegate
		}

		let responseTask = ETask { () async throws(NetworkError) in
			try await NetworkError.captureAndConvert {
				while urlTask.response == nil {
					try await Task.sleep(for: .milliseconds(100))
				}
				guard let response = urlTask.response else { fatalError() }

				return EngineResponseHeader(from: response)
			}
		}

		bodyContinuation.onFinish { reason in
			func performCancellation() {
				urlTask.cancel()
				responseTask.cancel()
			}
			switch reason {
			case .cancelled:
				performCancellation()
			case .finished(let error):
				if error != nil {
					performCancellation()
				}
			}
		}

		urlTask.resume()

		return (progStream, responseTask, bodyStream)
	}

	public func shutdown() {
		finishTasksAndInvalidate()
	}

	// hard coded into NetworkError - no need to implement here
	public static func isCancellationError(_ error: any Error) -> Bool { false }

	// hard coded into NetworkError - no need to implement here
	public static func isTimeoutError(_ error: any Error) -> Bool { false }
}
