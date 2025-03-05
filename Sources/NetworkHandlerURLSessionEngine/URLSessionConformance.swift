import NetworkHandler
import Foundation
import SwiftPizzaSnips
import Logging

extension URLSession: NetworkEngine {
	public static func asEngine(withConfiguration configuration: URLSessionConfiguration = .default) -> URLSession {
		let delegate = UploadDellowFelegate()
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.name = "Dellow Felegate"
		return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
	}

	public func fetchNetworkData(
		from request: DownloadEngineRequest,
		requestLogger: Logger?
	) async throws -> (EngineResponseHeader, ResponseBodyStream) {
		let urlRequest = request.urlRequest
		let (dlBytes, response) = try await bytes(for: urlRequest)

		let engResponse = EngineResponseHeader(from: response as! HTTPURLResponse)
		let (stream, continuation) = ResponseBodyStream.makeStream()

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

		continuation.onTermination = { reason in
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
		request: UploadEngineRequest,
		with payload: UploadFile,
		requestLogger: Logger?
	) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, any Error>,
		responseTask: Task<EngineResponseHeader, any Error>,
		responseBody: ResponseBodyStream
	) {
		let urlRequest = request.urlRequest

		let (progStream, progContinuation) = AsyncThrowingStream<Int64, Error>.makeStream()
		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream()

		let delegate = delegate as! UploadDellowFelegate

		let payloadStream: InputStream
		switch payload {
		case .data(let data):
			payloadStream = InputStream(data: data)
		case .localFile(let localFile):
			guard
				let stream = InputStream(url: localFile)
			else { throw UploadError.createStreamFromLocalFileFailed }
			payloadStream = stream
		case .streamProvider(let stream):
			payloadStream = stream
		case .inputStream(let stream):
			payloadStream = stream
		}

		let task = uploadTask(withStreamedRequest: urlRequest)
		delegate.addTask(
			task,
			withStream: payloadStream,
			progressContinuation: progContinuation,
			bodyContinuation: bodyContinuation)
		task.delegate = delegate

		let responseTask = Task {
			do {
				while task.response == nil {
					try await Task.sleep(for: .milliseconds(100))
				}
				guard let response = task.response else { fatalError() }
				
				return EngineResponseHeader(from: response)
			} catch {
				throw error
			}
		}

		bodyContinuation.onTermination = { reason in
			func performCancellation() {
				task.cancel()
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

		task.resume()

		return (progStream, responseTask, bodyStream)
	}

	public func shutdown() {
		finishTasksAndInvalidate()
	}
}
