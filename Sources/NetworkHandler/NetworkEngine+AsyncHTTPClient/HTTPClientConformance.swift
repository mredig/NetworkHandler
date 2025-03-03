import AsyncHTTPClient
import SwiftPizzaSnips
@preconcurrency import Foundation
import Swift
import NIOCore
import NIOHTTP1

extension HTTPClient: NetworkEngine {
	public func fetchNetworkData(
		from request: DownloadEngineRequest
	) async throws -> (EngineResponseHeader, ResponseBodyStream) {
		let httpClientRequest = request.httpClientRequest

		let httpClientResponse = try await execute(httpClientRequest, deadline: .distantFuture)

		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream()

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

		bodyContinuation.onTermination = { reason in
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
	
	public func uploadNetworkData(
		request: UploadEngineRequest,
		with payload: UploadEngineRequest.UploadFile
	) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, any Error>,
		response: _Concurrency.Task<EngineResponseHeader, any Error>,
		responseBody: ResponseBodyStream
	) {
		var httpClientRequest = try request.httpClientFutureRequest

		func streamWriter(
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
					_ = arrayBuffer.update(fromContentsOf: buffer)
					initializedCount = count
					print(count)
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
			else { throw UploadError.createStreamFromLocalFileFailed }
			httpClientRequest.body = .stream(contentLength: Int64(fileSize), { [fileStream] writer in
				streamWriter(inputStream: fileStream, writer: writer)
			})
		case .data(let data):
			httpClientRequest.body = .data(data)
		case .streamProvider(let streamProvider):
			httpClientRequest.body = .stream(contentLength: nil, { [streamProvider] writer in
				streamWriter(inputStream: streamProvider, writer: writer)
			})
		}

		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream()

		let (upProgStream, upProgContinuation) = AsyncThrowingStream<Int64, Error>.makeStream()

		let delegate = HTTPDellowFelegate(
			progressContinuation: upProgContinuation,
			bodyChunkContinuation: bodyContinuation)

		let responseTask = _Concurrency.Task {
			let head = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HTTPResponseHead, Error>) in
				delegate.setUploadContinuation(continuation)
			}

			return EngineResponseHeader(from: HTTPClientResponse(from: head), with: request.url)
		}

		_ = execute(request: httpClientRequest, delegate: delegate)

		return (upProgStream, responseTask, bodyStream)

//		let responseTask = _Concurrency.Task {
//			let httpClientResponse = try await execute(httpClientRequest, deadline: .distantFuture)
//			upProgContinuation.finish()
//			return httpClientResponse
//		}
//
//		let engineResponseTask = _Concurrency.Task {
//			let response = try await responseTask.value
//			return EngineResponseHeader(from: response, with: request.url)
//		}
//
//		let bodyTask = _Concurrency.Task {
//			do {
//				let response = try await responseTask.value
//				for try await buffer in response.body {
//					try bodyContinuation.yield(Array(buffer.readableBytesView))
//				}
//				try bodyContinuation.finish()
//			} catch {
//				try bodyContinuation.finish(throwing: error)
//			}
//		}
//
//		bodyContinuation.onTermination = { reason in
//			switch reason {
//			case .cancelled:
//				responseTask.cancel()
//				bodyTask.cancel()
//			case .finished(let error):
//				if error != nil {
//					responseTask.cancel()
//					bodyTask.cancel()
//				}
//			}
//		}

//		return (upProgStream, engineResponseTask, bodyStream)
	}
	
	public func shutdown() {
		shutdown { error in
			if let error {
				print("Error shutting down client: \(error)")
			}
		}
	}

	private class HTTPDellowFelegate: HTTPClientResponseDelegate {
		private let lock = MutexLock()

		private var bytesSent: Int64 = 0
		var progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation?
		private var alreadyUploaded: HTTPResponseHead?
		var bodyChunkContinuation: ResponseBodyStream.Continuation?
		var uploadContinuation: CheckedContinuation<HTTPResponseHead, Error>?

		init(
			progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation? = nil,
			bodyChunkContinuation: ResponseBodyStream.Continuation? = nil
		) {
			self.progressContinuation = progressContinuation
			self.bodyChunkContinuation = bodyChunkContinuation
		}

		func setUploadContinuation(_ continuation: CheckedContinuation<HTTPResponseHead, Error>) {
			lock.withLock {
				if let head = alreadyUploaded {
					continuation.resume(returning: head)
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
			lock.withLock {
				bytesSent += Int64(part.readableBytes)
				progressContinuation?.yield(bytesSent)
			}
		}

		func didReceiveHead(task: HTTPClient.Task<()>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
			lock.withLock {
				uploadContinuation?.resume(returning: head)
				uploadContinuation = nil
			}
			return task.eventLoop.makeSucceededVoidFuture()
		}

		func didReceiveBodyPart(task: HTTPClient.Task<()>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
			lock.withLock {
				do {
					try bodyChunkContinuation?.yield(Array(buffer.readableBytesView))
				} catch {
					_finish(throwing: error)
				}
			}
			return task.eventLoop.makeSucceededVoidFuture()
		}

		func didFinishRequest(task: AsyncHTTPClient.HTTPClient.Task<Void>) throws {
			lock.withLock {
				progressContinuation?.finish()
				try? bodyChunkContinuation?.finish()

				uploadContinuation = nil
				progressContinuation = nil
				bodyChunkContinuation = nil
			}
		}

		func didReceiveError(task: HTTPClient.Task<Void>, _ error: any Error) {
			lock.withLock {
				_finish(throwing: error)
			}
		}

		private func _finish(throwing error: Error) {
			progressContinuation?.finish(throwing: error)
			try? bodyChunkContinuation?.finish(throwing: error)
			uploadContinuation?.resume(throwing: error)

			uploadContinuation = nil
			progressContinuation = nil
			bodyChunkContinuation = nil
		}
	}
}
