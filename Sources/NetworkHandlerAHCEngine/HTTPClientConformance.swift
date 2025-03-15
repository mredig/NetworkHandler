@_exported import AsyncHTTPClient
import SwiftPizzaSnips
@preconcurrency import Foundation
import Swift
import NIOCore
import NIOHTTP1
import Logging
@_exported import NetworkHandler

extension HTTPClient: @retroactive Withable {}
extension HTTPClient: NetworkEngine {
	public func performNetworkTransfer(
		request: NetworkRequest,
		uploadProgressContinuation: UploadProgressStream.Continuation?,
		requestLogger: Logger?
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, responseBody: ResponseBodyStream) {
		switch request {
		case .general(let generalRequest):
			try await fetchNetworkData(from: generalRequest, requestLogger: requestLogger)
		case .upload(let uploadRequest, payload: let payload):
			try await uploadNetworkData(
				request: uploadRequest,
				with: payload,
				uploadProgressContinuation: uploadProgressContinuation,
				requestLogger: requestLogger)
		}
	}

	private func fetchNetworkData(
		from request: GeneralEngineRequest,
		requestLogger: Logger?
	) async throws(NetworkError) -> (EngineResponseHeader, ResponseBodyStream) {
		let httpClientRequest = request.httpClientRequest

		let httpClientResponse = try await NetworkError.captureAndConvert {
			do {
				return try await execute(httpClientRequest, deadline: .distantFuture)
			} catch let error as HTTPClientError {
				switch error {
				case .readTimeout, .writeTimeout, .connectTimeout:
					throw NetworkError.requestTimedOut
				case .cancelled, .requestStreamCancelled:
					throw NetworkError.requestCancelled
				default: throw error
				}
			}
		}

		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream(errorOnCancellation: CancellationError())

		let bodyTask = _Concurrency.Task {
			do {
				for try await chunk in httpClientResponse.body {
					let bytes = Array(chunk.readableBytesView)
					try bodyContinuation.yield(bytes)
				}
			} catch {
				try bodyContinuation.finish(throwing: error)
			}
			try bodyContinuation.finish()
		}

		bodyContinuation.onFinish { reason in
			switch reason {
			case .cancelled:
				bodyTask.cancel()
			case .finished(let error):
				if error != nil {
					bodyTask.cancel()
				}
			}
		}

		let engineResponse = EngineResponseHeader(from: httpClientResponse, with: request.url)
		return (engineResponse, bodyStream)
	}

	private func uploadNetworkData(
		request: UploadEngineRequest,
		with payload: UploadFile,
		uploadProgressContinuation upProgContinuation: UploadProgressStream.Continuation?,
		requestLogger: Logger?
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, responseBody: ResponseBodyStream) {
		var httpClientRequest = try NetworkError.captureAndConvert { try request.httpClientFutureRequest }

		@Sendable func streamWriter(
			inputStream: InputStream,
			writer: HTTPClient.Body.StreamWriter
		) -> EventLoopFuture<Void> {
			let bufferSize = 40960
			let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferSize)
			guard let bufferPointer = buffer.baseAddress else { fatalError("Cannot retrieve base address") }
			defer { buffer.deallocate() }

			var lastSuccess: EventLoopFuture<Void>?
			inputStream.open()
			while inputStream.hasBytesAvailable {
				let count = inputStream.read(bufferPointer, maxLength: bufferSize)
				let chunk = [UInt8](unsafeUninitializedCapacity: count) { arrayBuffer, initializedCount in
					_ = arrayBuffer.baseAddress?.update(from: bufferPointer, count: count)
					initializedCount = count
				}
				lastSuccess = writer.write(.byteBuffer(ByteBuffer(bytes: chunk)))
			}
			inputStream.close()
			return lastSuccess ?? writer.write(.byteBuffer(ByteBuffer()))
		}

		switch payload {
		case .localFile(let url):
			guard
				let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
				let fileStream = InputStream(url: url)
			else { throw .unspecifiedError(reason: "Creating a stream from the referenced local file failed. \(url)") }
			httpClientRequest.body = .stream(contentLength: Int64(fileSize), { [fileStream] writer in
				streamWriter(inputStream: fileStream, writer: writer)
			})
		case .data(let data):
			httpClientRequest.body = .data(data)
		case .inputStream(let stream):
			httpClientRequest.body = .stream(
				contentLength: request.expectedContentLength.flatMap(Int64.init), { [stream] writer in
					streamWriter(inputStream: stream, writer: writer)
				})
		}

		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)

		let timeoutDebouncer = TimeoutDebouncer(timeoutDuration: request.timeoutInterval) {
			bodyStream.cancel(throwing: NetworkError.requestTimedOut)
			try? upProgContinuation?.finish(throwing: NetworkError.requestTimedOut)
		}

		let delegate = HTTPDellowFelegate(
			progressContinuation: upProgContinuation,
			bodyChunkContinuation: bodyContinuation,
			timeoutDebouncer: timeoutDebouncer)

		let requestURL = request.url

		_ = execute(request: httpClientRequest, delegate: delegate)

		let ahcHead = try await NetworkError.captureAndConvert {
			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HTTPResponseHead, Error>) in
				delegate.setUploadContinuation(continuation)
			}
		}
		timeoutDebouncer.checkIn()

		let response = EngineResponseHeader(from: HTTPClientResponse(from: ahcHead), with: requestURL)

		return (response, bodyStream)
	}
	
	public func shutdown() {
		shutdown { error in
			if let error {
				print("Error shutting down client: \(error)")
			}
		}
	}

	private class HTTPDellowFelegate: HTTPClientResponseDelegate, @unchecked Sendable {
		private let lock = MutexLock()

		private var bytesSent: Int64 = 0
		var progressContinuation: UploadProgressStream.Continuation?
		private var alreadyUploaded: HTTPResponseHead?
		var bodyChunkContinuation: ResponseBodyStream.Continuation?
		var uploadContinuation: CheckedContinuation<HTTPResponseHead, Error>?
		let timeoutDebouncer: TimeoutDebouncer

		init(
			progressContinuation: UploadProgressStream.Continuation? = nil,
			bodyChunkContinuation: ResponseBodyStream.Continuation? = nil,
			timeoutDebouncer: TimeoutDebouncer
		) {
			self.progressContinuation = progressContinuation
			self.bodyChunkContinuation = bodyChunkContinuation
			self.timeoutDebouncer = timeoutDebouncer
		}

		func setUploadContinuation(_ continuation: CheckedContinuation<HTTPResponseHead, Error>) {
			lock.withLock {
				if let head = alreadyUploaded {
					continuation.resume(returning: head)
					timeoutDebouncer.cancelTimeout()
				} else {
					self.uploadContinuation = continuation
				}
			}
		}

//		func didSendRequest(task: HTTPClient.Task<()>) {
//			print(#function)
//		}

//		func didSendRequestHead(task: HTTPClient.Task<()>, _ head: HTTPRequestHead) {
//			print(#function)
//		}

		func didSendRequestPart(task: HTTPClient.Task<()>, _ part: IOData) {
			timeoutDebouncer.checkIn()
			lock.withLock {
				bytesSent += Int64(part.readableBytes)
				_ = try? progressContinuation?.yield(bytesSent)
			}
		}

		func didReceiveHead(task: HTTPClient.Task<()>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
			timeoutDebouncer.checkIn()
			lock.withLock {
				uploadContinuation?.resume(returning: head)
				uploadContinuation = nil
			}
			return task.eventLoop.makeSucceededVoidFuture()
		}

		func didReceiveBodyPart(task: HTTPClient.Task<()>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
			timeoutDebouncer.checkIn()
			lock.withLock {
				do {
					try bodyChunkContinuation?.yield(Array(buffer.readableBytesView))
				} catch {
					_finish(throwing: error)
				}
			}
			return task.eventLoop.makeSucceededVoidFuture()
		}

		func didFinishRequest(task: HTTPClient.Task<Void>) throws {
			timeoutDebouncer.checkIn()
			lock.withLock {
				try? progressContinuation?.finish()
				try? bodyChunkContinuation?.finish()

				uploadContinuation = nil
				progressContinuation = nil
				bodyChunkContinuation = nil
			}
		}

		func didReceiveError(task: HTTPClient.Task<Void>, _ error: any Error) {
			timeoutDebouncer.cancelTimeout()
			lock.withLock {
				_finish(throwing: error)
			}
		}

		private func _finish(throwing error: Error) {
			timeoutDebouncer.cancelTimeout()
			try? progressContinuation?.finish(throwing: error)
			try? bodyChunkContinuation?.finish(throwing: error)
			uploadContinuation?.resume(throwing: error)

			uploadContinuation = nil
			progressContinuation = nil
			bodyChunkContinuation = nil
		}
	}

	public static func isCancellationError(_ error: any Error) -> Bool {
		guard let httpError = error as? HTTPClientError else { return false }
		switch httpError {
		case .cancelled, .requestStreamCancelled:
			return true
		default: return false
		}
	}

	public static func isTimeoutError(_ error: any Error) -> Bool {
		guard let httpError = error as? HTTPClientError else { return false }
		switch httpError {
		case .readTimeout, .writeTimeout, .connectTimeout:
			return true
		default: return false
		}
	}
}
