import Foundation
import Logging
import NetworkHandler
import SwiftPizzaSnips
import Algorithms

public actor MockingEngine: NetworkEngine {
	public var acceptedIntercepts: [Key: SmartResponseMockBlock] { get async { await server.acceptedIntercepts } }

	let server = MockingServer()

	public init() {}

	public func addMock(
		for url: URL,
		method: HTTPMethod,
		responseData: Data?,
		responseCode: Int,
		delay: TimeInterval = 0
	) async {
		await addMock(for: url, method: method) { server, request, _, _ in
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
		from request: GeneralEngineRequest,
		requestLogger: Logger?
	) async throws(NetworkError) -> (EngineResponseHeader, ResponseBodyStream) {
		try await performServerInteraction(for: .general(request), uploadProgCont: nil)
	}

	public func performNetworkTransfer(
		request: NetworkRequest,
		uploadProgressContinuation: UploadProgressStream.Continuation?,
		requestLogger: Logger?
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, responseBody: ResponseBodyStream) {
		try await performServerInteraction(for: request, uploadProgCont: uploadProgressContinuation)
	}

	private func performServerInteraction(
		for request: NetworkRequest,
		uploadProgCont: UploadProgressStream.Continuation?
	) async throws(NetworkError) -> (
		responseHeader: EngineResponseHeader,
		responseBody: ResponseBodyStream
	) {
		let (responseStream, responseContinuation) = ResponseBodyStream.makeStream(
			errorOnCancellation: NetworkError.requestCancelled)

		let headerTrackDelegate = HeaderTrackingDelegate()

		let transferTask = Task {
			try await serverTransfer(
				request: request,
				uploadProgressContinuation: uploadProgCont,
				responseContinuation: responseContinuation,
				headerDelegate: headerTrackDelegate)
		}

		uploadProgCont?.onFinish { reason in
			guard let error = reason.finishedOrCancelledError else { return }
			headerTrackDelegate.setValue(.failure(error))
			responseStream.cancel(throwing: error)
			transferTask.cancel()
		}

		responseStream.onFinish {  reason in
			guard let error = reason.finishedOrCancelledError else { return }
			headerTrackDelegate.setValue(.failure(error))
			try? uploadProgCont?.finish(throwing: error)
			transferTask.cancel()
		}

		Task {
			// this is a simple, naiive timeout, not activity based. This should be fine for the purposes of running
			// tests given that there's no latency between the client and remote when it's the same host.
			try await Task.sleep(for: .seconds(request.timeoutInterval))
			responseStream.cancel(throwing: NetworkError.requestTimedOut)
			try? uploadProgCont?.finish(throwing: NetworkError.requestTimedOut)
		}

		let response = try await NetworkError.captureAndConvert {
			try await withCheckedThrowingContinuation { continuation in
				headerTrackDelegate.setContinuation(continuation)
			}
		}

		return (response, responseStream)
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
		uploadProgressContinuation: UploadProgressStream.Continuation?,
		responseContinuation: ResponseBodyStream.Continuation,
		headerDelegate: HeaderTrackingDelegate
	) async throws(NetworkError) {
		let (sendStream, sendContinuation) = MockingServer.ServerStream.makeStream(
			errorOnCancellation: NetworkError.requestCancelled)
		let (serverStream, serverContinuation) = MockingServer.ServerStream.makeStream(
			errorOnCancellation: NetworkError.requestCancelled)

		defer { headerDelegate.setValue(.failure(NetworkError.requestCancelled)) }

		Task {
			try await server.openConnection(sendStream: sendStream, responseStreamContinuation: serverContinuation)
		}

		return try await NetworkError.captureAndConvert {
			try await Task.sleep(for: .milliseconds(20))
			try sendContinuation.yield(.requestHeader(request))

			func sendStream(_ stream: InputStream) async throws(NetworkError) {
				try await NetworkError.captureAndConvert { [stream] in
					defer { try? uploadProgressContinuation?.finish() }
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
						try uploadProgressContinuation?.yield(totalSent)
					}
				}
			}

			defer { try? sendContinuation.finish() }
			switch request {
			case .general(let downloadRequest):
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
				case .inputStream(let inputStream):
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

		public var mockStorage: [String: Data] = [:]

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
			var pathItems: [String: String] = [:]
			for try await chunk in sendStream {
				try await Task.sleep(for: .milliseconds(20))
				switch chunk {
				case .requestHeader(let netrequest):
					let key = Key(url: netrequest.url, method: netrequest.method)
					responseBlock = acceptedIntercepts[key]
					if
						responseBlock == nil,
						let dynamicResponse = acceptedIntercepts.first(where: { $0.key.respondsTo(key) })
					{
						responseBlock = dynamicResponse.value
						pathItems = dynamicResponse.key.pathItems(from: netrequest.url)
					}
					header = netrequest
				case .bodyStreamChunk(let clientBodyChunk):
					if bodyAccumulator == nil { bodyAccumulator = Data() }
					bodyAccumulator?.append(contentsOf: clientBodyChunk)
				case .responseHeader:
					fatalError("client sent server response")
				}
			}

			guard let responseBlock, let header else {
				try responseStreamContinuation
					.yield(.responseHeader(EngineResponseHeader(status: 404, url: header?.url, headers: [:])))
				try responseStreamContinuation.finish()
				return
			}

			let processedResponse = try await responseBlock(self, header, pathItems, bodyAccumulator)
			defer { try? responseStreamContinuation.finish() }
			try await Task.sleep(for: .milliseconds(20))

			try responseStreamContinuation.yield(.responseHeader(processedResponse.response))

			guard let responseData = processedResponse.data else { return }
			for chunk in responseData.chunks(ofCount: 1024 * 1024 * 1) {
				try await Task.sleep(for: .milliseconds(20))
				try responseStreamContinuation.yield(.bodyStreamChunk(Array(chunk)))
			}
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

			public func pathItems(from requestURL: URL) -> [String: String] {
				let components = url.pathComponents
				let requestComponents = Self.stripQuery(from: requestURL).pathComponents

				var accum: [String: String] = [:]
				for (comp, req) in zip(components, requestComponents) {
					guard comp.starts(with: ":") else { continue }
					accum[String(comp.dropFirst())] = req
				}
				return accum
			}

			public func respondsTo(_ key: Key) -> Bool {
				let stripped = key.url
				guard key.method == method else { return false }
				guard self.url != stripped else { return true }

				guard self.url.host()?.lowercased() == url.host()?.lowercased() else { return false }

				let selfComponents = self.url.pathComponents
				let requestComponents = stripped.pathComponents

				guard requestComponents.count >= selfComponents.count else {
					return false
				}
				for (a, b) in zip(selfComponents, requestComponents) {
					guard a != b else { continue }
					if a.first == ":" {
						continue
					} else if a == "*" {
						continue
					}
					return false
				}

				if requestComponents.count == selfComponents.count {
					return true
				} else {
					return selfComponents.last == "*"
				}
			}
		}

		public typealias SmartResponseMockBlock = @Sendable (
			_ server: isolated MockingServer,
			_ request: NetworkRequest,
			_ requestPathArguments: [String: String],
			_ requestBody: Data?
		) async throws -> (data: Data?, response: EngineResponseHeader)
	}
}
