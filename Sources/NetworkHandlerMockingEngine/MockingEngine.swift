import Foundation
import Logging
import NetworkHandler
import SwiftPizzaSnips
import Algorithms

public actor MockingEngine: NetworkEngine {
	public var acceptedIntercepts: [Key: SmartResponseMockBlock] { get async { await server.acceptedIntercepts } }

	public var mockStorage: [String: Data]  { get async { await server.mockStorage } }

	let server = MockingServer()

	public init() {}

	public func addMock(for url: URL, method: HTTPMethod, responseData: Data?, responseCode: Int, delay: TimeInterval = 0) async {
		await addMock(for: url, method: method) { server, request, _ in
			if delay > 0 {
				try await Task.sleep(for: .seconds(delay))
			}
			let headers: HTTPHeaders
			if let responseData {
				headers = [
					.contentLength: "\(responseData.count)"
				]
			} else {
				headers = [:]
			}
			return (responseData,  EngineResponseHeader(status: responseCode, url: request.url, headers: headers))
		}
	}

	public func addMock(
		for url: URL,
		method: HTTPMethod,
		smartBlock: @escaping @Sendable SmartResponseMockBlock
	) async {
		let key = Key(url: url, method: method)
		await server.modifyProperties {
			$0.acceptedIntercepts[key] = smartBlock
		}
	}

	public func fetchNetworkData(
		from request: DownloadEngineRequest,
		requestLogger: Logger?
	) async throws(NetworkError) -> (EngineResponseHeader, ResponseBodyStream) {

		let (_, headerTask, responseStream) = try await performServerInteraction(for: .download(request))

		let header = try await headerTask.value
		return (header, responseStream)
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
		let uploadSize: Int? = {
			switch payload {
			case .data(let data):
				return data.count
			case .localFile(let fileURL):
				return try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
			case .streamProvider(let streamProvider):
				return streamProvider.totalStreamBytes
			case .inputStream:
				return nil
			}
		}()

		request.expectedContentLength = uploadSize

		return try await performServerInteraction(for: .upload(request, payload: payload))
	}

	private func performServerInteraction(for request: NetworkRequest) async throws(NetworkError) -> (
		uploadProgress: UploadProgressStream,
		responseTask: ETask<EngineResponseHeader, NetworkError>,
		responseBody: ResponseBodyStream
	) {
		let (uploadProgStream, uploadProgCont) = UploadProgressStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)
		let (responseStream, responseContinuation) = ResponseBodyStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)

		let headerTrackDelegate = HeaderTrackingDelegate()

		let responseHeaderTask = ETask { () async throws(NetworkError) -> EngineResponseHeader in
			try await NetworkError.captureAndConvert {
				try await withCheckedThrowingContinuation { continuation in
					headerTrackDelegate.setContinuation(continuation)
				}
			}
		}

		let transferTask = Task {
			try await serverTransfer(
				request: request,
				uploadProgressContinuation: uploadProgCont,
				responseContinuation: responseContinuation,
				headerDelegate: headerTrackDelegate)
		}

		uploadProgStream.onFinish { reason in
			guard let error = reason.finishedOrCancelledError else { return }
			headerTrackDelegate.setValue(.failure(error))
			responseStream.cancel(throwing: error)
			transferTask.cancel()
		}

		responseStream.onFinish {  reason in
			guard let error = reason.finishedOrCancelledError else { return }
			headerTrackDelegate.setValue(.failure(error))
			uploadProgStream.cancel(throwing: error)
			transferTask.cancel()
		}

		Task {
			try await Task.sleep(for: .seconds(request.timeoutInterval))
			responseStream.cancel(throwing: NetworkError.requestTimedOut)
			uploadProgStream.cancel(throwing: NetworkError.requestTimedOut)
		}

		return (uploadProgStream, responseHeaderTask, responseStream)
	}

	private class HeaderTrackingDelegate: @unchecked Sendable {
		private let lock = MutexLock()

		private var continuation: CheckedContinuation<EngineResponseHeader, Error>?
		private var bufferedValue: Result<EngineResponseHeader, Error>?
		private var isFinished = false

		func setContinuation(_ continuation: CheckedContinuation<EngineResponseHeader, Error>) {
			lock.withLock {
				guard isFinished == false else { return }
				if let existing = bufferedValue {
					continuation.resume(with: existing)
					bufferedValue = nil
					isFinished = true
				} else {
					self.continuation = continuation
				}
			}
		}

		func setValue(_ value: Result<EngineResponseHeader, Error>) {
			lock.withLock {
				guard isFinished == false else { return }
				if let existing = continuation {
					existing.resume(with: value)
					continuation = nil
					isFinished = true
				} else {
					bufferedValue = value
				}
			}
		}
	}

	private func serverTransfer(
		request: NetworkRequest,
		uploadProgressContinuation: UploadProgressStream.Continuation,
		responseContinuation: ResponseBodyStream.Continuation,
		headerDelegate: HeaderTrackingDelegate
	) async throws(NetworkError) {
		let (sendStream, sendContinuation) = MockingServer.ServerStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)
		let (serverStream, serverContinuation) = MockingServer.ServerStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)

		defer { headerDelegate.setValue(.failure(NetworkError.requestCancelled)) }

		Task {
			try await server.openConnection(sendStream: sendStream, responseStreamContinuation: serverContinuation)
		}

		return try await NetworkError.captureAndConvert {
			try await Task.sleep(for: .milliseconds(20))
			try sendContinuation.yield(.requestHeader(request))

			func sendStream(_ stream: InputStream) async throws(NetworkError) {
				try await NetworkError.captureAndConvert { [stream] in
					defer { try? uploadProgressContinuation.finish() }
					let bufferSize = 1024 * 1024 * 1 // 1 MB
					let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 1024 * 1024 * 4)
					defer { buffer.deallocate() }
					guard let bufferPointer = buffer.baseAddress else {
						throw NetworkError.unspecifiedError(reason: "Failure to create buffer")
					}

					var totalSent: Int64 = 0
					stream.open()
					defer { stream.close() }
					while stream.hasBytesAvailable {
						try await Task.sleep(for: .milliseconds(200))
						try Task.checkCancellation()
						let bytesRead = stream.read(bufferPointer, maxLength: bufferSize)
						let data = Data(bytes: bufferPointer, count: bytesRead)
						try sendContinuation.yield(.bodyStreamChunk(Array(data)))
						totalSent += Int64(bytesRead)
						try uploadProgressContinuation.yield(totalSent)
					}
				}
			}

			defer { try? sendContinuation.finish() }
			switch request {
			case .download(let downloadRequest):
				if let sendBody = downloadRequest.payload {
					for chunk in sendBody.chunks(ofCount: 1024) {
						try await Task.sleep(for: .milliseconds(20))
						try sendContinuation.yield(.bodyStreamChunk(Array(chunk)))
					}
				}
			case .upload(_, payload: let payload):
				switch payload {
				case .data(let data):
					let stream = InputStream(data: data)
					try await sendStream(stream)
				case .localFile(let localFile):
					guard
						let stream = InputStream(url: localFile)
					else { throw NetworkError.unspecifiedError(reason: "Error opening file for mock upload") }
					try await sendStream(stream)
				case .inputStream(let inputStream), .streamProvider(let inputStream as InputStream):
					try await sendStream(inputStream)
				}
			}
			try sendContinuation.finish()

			var serverIterator = serverStream.makeAsyncIterator()

			guard let headerChunk = try await serverIterator.next() else {
				throw NetworkError.unspecifiedError(reason: "No response header")
			}
			guard case .responseHeader(let responseHeader) = headerChunk else {
				throw NetworkError.unspecifiedError(reason: "Got response without header")
			}

			headerDelegate.setValue(.success(responseHeader))

			try await withTaskCancellationHandler(
				operation: {
					do {
						while let chunkEnum = try await serverIterator.next() {
							guard case .bodyStreamChunk(let chunk) = chunkEnum else {
								continue
							}

							try responseContinuation.yield(chunk)
						}
						try responseContinuation.finish()
					} catch {
						try responseContinuation.finish(throwing: error)
					}
				},
				onCancel: {
					try? responseContinuation.finish(throwing: NetworkError.requestCancelled)
				})
		}
	}

	public static func noMockCreated404ErrorText(for request: NetworkRequest) -> String {
		"No mock for \(request.url) (\(request.method.rawValue))"
	}

	nonisolated
	public func shutdown() {}

	public static func isCancellationError(_ error: any Error) -> Bool { false }
	public static func isTimeoutError(_ error: any Error) -> Bool { false }

	public typealias Key = MockingServer.Key
	public typealias SmartResponseMockBlock = MockingServer.SmartResponseMockBlock
}

extension MockingEngine {
	public actor MockingServer {
		var acceptedIntercepts: [Key: SmartResponseMockBlock] = [:]

		var mockStorage: [String: Data] = [:]

		func modifyProperties<E: Error>(_ block: @Sendable (isolated MockingServer) throws(E) -> Void) throws(E) {
			try block(self)
		}

		func openConnection(
			sendStream: ServerStream,
			responseStreamContinuation: ServerStream.Continuation
		) async throws {
			var header: NetworkRequest?
			var responseBlock: SmartResponseMockBlock?
			var bodyAccumulator: Data?
			for try await chunk in sendStream {
				try await Task.sleep(for: .milliseconds(20))
				switch chunk {
				case .requestHeader(let netrequest):
					let key = Key(url: netrequest.url, method: netrequest.method)
					responseBlock = acceptedIntercepts[key]
					header = netrequest
				case .bodyStreamChunk(let clientBodyChunk):
					if bodyAccumulator == nil { bodyAccumulator = Data() }
					bodyAccumulator?.append(contentsOf: clientBodyChunk)
				case .responseHeader:
					fatalError("client sent server response")
				}
			}

			guard let responseBlock, let header else {
				try responseStreamContinuation.yield(.responseHeader(EngineResponseHeader(status: 404, url: header?.url, headers: [:])))
				try responseStreamContinuation.finish()
				return
			}

			let processedResponse = try await responseBlock(self, header, bodyAccumulator)
			defer { try? responseStreamContinuation.finish() }
			try await Task.sleep(for: .milliseconds(20))

			try responseStreamContinuation.yield(.responseHeader(processedResponse.response))

			guard let responseData = processedResponse.data else { return }
			for chunk in responseData.chunks(ofCount: 1024 * 1024 * 1) {
				try await Task.sleep(for: .milliseconds(20))
				try responseStreamContinuation.yield(.bodyStreamChunk(Array(chunk)))
			}
		}

		func processMock(
			_ request: NetworkRequest,
			interceptor: @escaping @Sendable SmartResponseMockBlock,
			logger: Logger?
		) async throws(NetworkError) -> (
			uploadProgress: UploadProgressStream,
			responseTask: ETask<EngineResponseHeader, NetworkError>,
			responseBody: ResponseBodyStream
		) {
			let (uploadProgress, responseTask, responseBody) = try await self._processMock(request, interceptor: interceptor, logger: logger)

			// poor substitute for a real timeout
			Task {
				try await Task.sleep(for: .seconds(request.timeoutInterval))
				responseBody.cancel(throwing: URLError(.timedOut))
			}

			return (uploadProgress, responseTask, responseBody)
		}

		private func _processMock(
			_ request: NetworkRequest,
			interceptor: @escaping @Sendable SmartResponseMockBlock,
			logger: Logger?
		) async throws(NetworkError) -> (
			uploadProgress: UploadProgressStream,
			responseTask: ETask<EngineResponseHeader, NetworkError>,
			responseBody: ResponseBodyStream
		) {
			let (upProg, upProgCont) = UploadProgressStream.makeStream(errorOnCancellation: NetworkError.requestCancelled)
			let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream(errorOnCancellation: CancellationError())

			let everythingTask = ETask { () async throws(NetworkError) in
				try await NetworkError.captureAndConvert {
					let clientData = try await loadFromClient(
						request,
						sendProgContinuation: upProgCont,
						logger: logger)
					try upProgCont.finish()

					return try await interceptor(self, request, clientData)
				}
			}

			let responseTask = ETask { () async throws(NetworkError) in
				try await everythingTask.value.response
			}

			Task {
				guard
					let responseBody = try await everythingTask.value.data
				else {
					try bodyContinuation.finish()
					return
				}

				let size = 1024 * 1024 // 1 MB

				do {
					for chunk in responseBody.chunks(ofCount: size) {
						try Task.checkCancellation()
						try bodyContinuation.yield(Array(chunk))
						try await Task.sleep(for: .milliseconds(20))
					}
					try bodyContinuation.finish()
				} catch {
					try bodyContinuation.finish(throwing: error)
				}
			}

			upProgCont.onFinish { reason in
				switch reason {
				case .cancelled:
					everythingTask.cancel()
				case .finished(let error):
					guard error != nil else { return }
					everythingTask.cancel()
				@unknown default:
					print("Unexpected reason. Cancelling: \(reason)")
					everythingTask.cancel()
				}
			}

			bodyContinuation.onFinish { reason in
				switch reason {
				case .cancelled:
					everythingTask.cancel()
				case .finished(let error):
					guard error != nil else { return }
					everythingTask.cancel()
				}
			}

			return (upProg, responseTask, bodyStream)
		}

		private func loadFromClient(
			_ request: NetworkRequest,
			sendProgContinuation: UploadProgressStream.Continuation,
			logger: Logger?
		) async throws(NetworkError) -> Data? {
			logger?.debug("Loading request from client", metadata: ["URL": "\(request.url)"])

			func streamToData(_ stream: InputStream) async throws(NetworkError) -> Data {
				try await NetworkError.captureAndConvert {
					defer { try? sendProgContinuation.finish() }
					let bufferSize = 1024 * 1024 * 1 // 1 MB
					let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 1024 * 1024 * 4)
					defer { buffer.deallocate() }
					guard let bufferPointer = buffer.baseAddress else {
						throw NetworkError.unspecifiedError(reason: "Failure to create buffer")
					}

					var totalSent: Int64 = 0
					stream.open()
					defer { stream.close() }
					var accumulator = Data()
					while stream.hasBytesAvailable {
						try await Task.sleep(for: .milliseconds(200))
						try Task.checkCancellation()
						let bytesRead = stream.read(bufferPointer, maxLength: bufferSize)
						accumulator.append(bufferPointer, count: bytesRead)
						totalSent += Int64(bytesRead)
						try sendProgContinuation.yield(totalSent)
					}
					return accumulator
				}
			}

			var data: Data?
			switch request {
			case .upload(_, let payload):
				switch payload {
				case .localFile(let url):
					guard
						let inputStream = InputStream(url: url)
					else { throw .unspecifiedError(reason: "Error opening file for mock upload") }
					data = try await streamToData(inputStream)
				case .data(let inData):
					let inputStream = InputStream(data: inData)
					data = try await streamToData(inputStream)
				case .streamProvider(let streamProvider):
					data = try await streamToData(streamProvider)
				case .inputStream(let stream):
					data = try await streamToData(stream)
				}
			case .download(let downloadEngineRequest):
				data = downloadEngineRequest.payload
			}

			return data
		}


		enum TransferChunk {
			case requestHeader(NetworkRequest)
			case bodyStreamChunk([UInt8])
			case responseHeader(EngineResponseHeader)
		}

		typealias ServerStream = AsyncCancellableThrowingStream<TransferChunk, Error>

		public func addStorage(_ blob: Data, forKey key: String) {
			mockStorage[key] = blob
		}

		public struct Key: Hashable, Sendable {
			public let url: URL
			public let method: HTTPMethod

			init(url: URL, method: HTTPMethod) {
				self.url = Key.stripQuery(from: url)
				self.method = method
			}

			static func stripQuery(from url: URL) -> URL {
				var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
				components?.queryItems = nil
				return components!.url!
			}
		}

		public typealias SmartResponseMockBlock = @Sendable (
			_ server: isolated MockingServer,
			_ request: NetworkRequest,
			_ requestBody: Data?
		) async throws -> (data: Data?, response: EngineResponseHeader)
	}
}
