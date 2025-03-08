import Foundation
import Logging
import NetworkHandler
import SwiftPizzaSnips
import Algorithms

public actor MockingEngine: NetworkEngine {
	public let passthroughEngine: (any NetworkEngine)?

	public var acceptedIntercepts: [Key: SmartResponseMockBlock] { get async { await server.acceptedIntercepts } }

	public var mockStorage: [String: Data]  { get async { await server.mockStorage } }

	let server = MockingServer()

	public init(
		passthroughEngine: (any NetworkEngine)?
	) {
		self.passthroughEngine = passthroughEngine
	}

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
		let key = Key(url: request.url, method: request.method)

		if let interceptor = await acceptedIntercepts[key] {
			requestLogger?.debug(
				"Mocking network fetch.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])
			let mock = try await server.processMock(
				.download(request),
				interceptor: interceptor,
				logger: requestLogger)
			return try await (mock.responseTask.value, mock.responseBody)
		} else if let passthroughEngine {
			requestLogger?.debug(
				"Requested fetch URL/Method combo not mocked. Passing through to passthrough engine.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])
			return try await passthroughEngine.fetchNetworkData(from: request, requestLogger: requestLogger)
		} else {
			requestLogger?.debug(
				"Requested fetch URL/Method combo not mocked, nor is any passthrough engine provided.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])

			throw NetworkError.httpUnexpectedStatusCode(
				code: 404,
				originalRequest: NetworkRequest.download(request),
				data: Self.noMockCreated404ErrorText(for: .download(request)).data(using: .utf8))
		}
	}

	public func uploadNetworkData(
		request: UploadEngineRequest,
		with payload: UploadFile,
		requestLogger: Logger?
	) async throws(NetworkError) -> (
		uploadProgress: UploadProgressStream,
		responseTask: ETask<EngineResponseHeader, NetworkError>,
		responseBody: ResponseBodyStream
	) {
		let key = Key(url: request.url, method: request.method)

		if let interceptor = await acceptedIntercepts[key] {
			requestLogger?.debug(
				"Mocking network upload.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])
			return try await server.processMock(
				.upload(request, payload: payload),
				interceptor: interceptor,
				logger: requestLogger)
		} else if let passthroughEngine {
			requestLogger?.debug(
				"Requested upload URL/Method combo not mocked. Passing through to passthrough engine.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])
			return try await passthroughEngine.uploadNetworkData(request: request, with: payload, requestLogger: requestLogger)
		} else {
			requestLogger?.debug(
				"Requested upload URL/Method combo not mocked, nor is any passthrough engine provided.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])

			throw NetworkError.httpUnexpectedStatusCode(
				code: 404,
				originalRequest: NetworkRequest.upload(request, payload: payload),
				data: Self.noMockCreated404ErrorText(for: .upload(request, payload: payload)).data(using: .utf8))
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
