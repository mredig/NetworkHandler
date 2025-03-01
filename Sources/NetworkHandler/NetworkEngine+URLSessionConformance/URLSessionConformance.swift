import NetworkHalpers
import Foundation
import SwiftPizzaSnips

extension URLSession: NetworkEngine {
	public static func asEngine() -> NetworkEngine {
		let delegate = UploadDellowFelegate()
		let config = URLSessionConfiguration.default
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.name = "Dellow Felegate"
		let newSession = URLSession(configuration: config, delegate: delegate, delegateQueue: queue)

		return newSession
	}

	public func fetchNetworkData(from request: DownloadEngineRequest) async throws -> (EngineResponseHeader, ResponseBodyStream) {
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

	public func uploadNetworkData(with request: UploadEngineRequest) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, any Error>,
		response: Task<EngineResponseHeader, any Error>,
		responseBody: ResponseBodyStream
	) {
		var urlRequest = request.urlRequest
		guard
			let payloadStream = urlRequest.httpBodyStream
		else { throw UploadError.noInputStream }
		urlRequest.httpBodyStream = nil

		let (progStream, progContinuation) = AsyncThrowingStream<Int64, Error>.makeStream()
		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream()

		let delegate = delegate as! UploadDellowFelegate

		let task = uploadTask(withStreamedRequest: urlRequest)
		delegate.addTaskWith(
			stream: payloadStream,
			progressContinuation: progContinuation,
			bodyContinuation: bodyContinuation,
			task: task)
		task.delegate = delegate

		let responseTask = Task {
			do {
				while task.response == nil {
					try await Task.sleep(for: .milliseconds(100))
				}
//				try await Task.sleep(for: .seconds(100))
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

	public enum UploadError: Error {
		case noServerResponseHeader
		case noInputStream
		case notTrackingRequestedTask
	}
}
