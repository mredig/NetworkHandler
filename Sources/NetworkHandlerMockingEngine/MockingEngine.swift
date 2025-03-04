import Foundation
import Logging
import NetworkHandler
import SwiftPizzaSnips
import Algorithms

public actor MockingEngine: NetworkEngine {
	public let passthroughEngine: NetworkEngine?

	public private(set) var acceptedIntercepts: [Key: SmartResponseMockBlock] = [:]

	public init(
		passthroughEngine: NetworkEngine?
	) {
		self.passthroughEngine = passthroughEngine
	}

	public func addMock(for url: URL, method: HTTPMethod, responseData: Data, responseCode: Int) {
		addMock(for: url, method: method) { request, _ in
			(responseData,  EngineResponseHeader(status: responseCode, url: request.url, headers: [
				.contentLength: "\(responseData.count)"
			]))
		}
	}

	public func addMock(
		for url: URL,
		method: HTTPMethod,
		smartBlock: @escaping @Sendable SmartResponseMockBlock
	) {
		let key = Key(url: url, method: method)
		acceptedIntercepts[key] = smartBlock
	}

	public func fetchNetworkData(
		from request: DownloadEngineRequest,
		requestLogger: Logger?
	) async throws -> (EngineResponseHeader, ResponseBodyStream) {
		let key = Key(url: request.url, method: request.method)

		if let interceptor = acceptedIntercepts[key] {
			requestLogger?.debug(
				"Mocking network fetch.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])
			let mock = try await processMock(
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

			throw MockError.notHandled404
		}
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
		let key = Key(url: request.url, method: request.method)

		if let interceptor = acceptedIntercepts[key] {
			requestLogger?.debug(
				"Mocking network upload.",
				metadata: [
					"URL": "\(request.url.path(percentEncoded: false))",
					"Method": "\(request.method.rawValue)"
				])
			return try await processMock(
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

			throw MockError.notHandled404
		}
	}

	private func processMock(
		_ request: NetworkRequest,
		interceptor: @escaping @Sendable SmartResponseMockBlock,
		logger: Logger?
	) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, any Error>,
		responseTask: Task<EngineResponseHeader, any Error>,
		responseBody: ResponseBodyStream
	) {
		let (upProg, upProgCont) = AsyncThrowingStream<Int64, Error>.makeStream()
		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream()

		let everythingTask = Task {
			let clientData = try await loadFromClient(
				request,
				sendProgContinuation: upProgCont,
				logger: logger)
			upProgCont.finish()

			return try await interceptor(request, clientData)
		}

		let responseTask = Task {
			try await everythingTask.value.response
		}

		Task {
			let responseBody = try await everythingTask.value.data
			let size = 1024 * 1024 // 1 MB

			for chunk in responseBody.chunks(ofCount: size) {
				try bodyContinuation.yield(Array(chunk))
			}
			try bodyContinuation.finish()
		}

		bodyContinuation.onTermination = { reason in
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
		sendProgContinuation: AsyncThrowingStream<Int64, Error>.Continuation,
		logger: Logger?
	) async throws -> Data? {
		logger?.debug("Loading request from client", metadata: ["URL": "\(request.url)"])

		func streamToData(_ stream: InputStream) async throws -> Data {
			let bufferSize = 1024 * 1024 * 4 // 4 MB
			let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 1024 * 1024 * 4)
			defer { buffer.deallocate() }
			guard let bufferPointer = buffer.baseAddress else { throw SimpleError(message: "Failure to create buffer") }

			var totalSent: Int64 = 0
			stream.open()
			defer { stream.close() }
			var accumulator = Data()
			while stream.hasBytesAvailable {
				let bytesRead = stream.read(bufferPointer, maxLength: bufferSize)
				accumulator.append(bufferPointer, count: bytesRead)
				totalSent += Int64(bytesRead)
				sendProgContinuation.yield(totalSent)
			}
			return accumulator
		}

		var data: Data?
		switch request {
		case .upload(_, let payload):
			switch payload {
			case .localFile(let url):
				guard
					let inputStream = InputStream(url: url)
				else { throw SimpleError(message: "Error opening file for mock upload") }
				data = try await streamToData(inputStream)
			case .data(let inData):
				let inputStream = InputStream(data: inData)
				data = try await streamToData(inputStream)
			case .streamProvider(let streamProvider):
				data = try await streamToData(streamProvider)
			}
		case .download(let downloadEngineRequest):
			data = downloadEngineRequest.payload
		}

		return data
	}

	nonisolated
	public func shutdown() {}

	public typealias SmartResponseMockBlock = (
		_ request: NetworkRequest,
		_ requestBody: Data?
	) async throws -> (data: Data, response: EngineResponseHeader)

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

	public enum MockError: Swift.Error {
		case notHandled404
	}
}
