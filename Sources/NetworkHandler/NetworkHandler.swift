import Foundation
@_exported import NetworkHalpers
import SwiftPizzaSnips
import Logging

/// The bread and butter of this package!
///
/// `NetworkHandler` is the central location housing the high level logic for how to handle networking.
///
/// All of the transfer methods are foundationally built off of `streamMahDatas()`, implementing the specific behavior
/// required for each individual method.
public class NetworkHandler<Engine: NetworkEngine>: @unchecked Sendable, Withable {
	// MARK: - Properties
	public let logger: Logger

	/**
	 An instance of Network Cache to speed up subsequent requests. Usage is
	 optional, but automatic when making requests using the `usingCache` flag.
	 */
	let cache: NetworkCache
	
	/// Used to label this instance of `NetworkHandler` for things like logging or debugging. Also useful
	/// if you desire anthropomorphizing `NetworkHandler` instances as they are created ephemerally in
	/// memory only to be ruthlessly destroyed once their usefulness has expired. I call this instance "Jimi".
	public let name: String

	/// Underlying engine running network transactions
	public let engine: Engine

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init(
		name: String,
		engine: Engine,
		logger: Logger = Logger(label: "Network Handler"),
		cacheLogger: Logger = Logger(label: "Network Handler Cache"),
		diskCacheCapacity: UInt64 = .max
	) {
		self.name = name
		self.cache = NetworkCache(name: "\(name)-Cache", logger: cacheLogger, diskCacheCapacity: diskCacheCapacity)
		self.logger = logger

		self.engine = engine

		NetworkError.registerTimeoutErrorHandling(Engine.isTimeoutError, forEngine: "\(Engine.self)")
		NetworkError.registerCancellationErrorHandling(Engine.isTimeoutError, forEngine: "\(Engine.self)")
	}

	deinit {
		engine.shutdown()
	}

	/// Clears the contents of the cache either in memory, on disk, or both.
	///
	/// - Parameters:
	///   - memory: A Boolean value indicating whether to clear the in-memory cache. Defaults to `true`.
	///   - disk: A Boolean value indicating whether to clear the disk cache. Defaults to `true`.
	///
	/// Use this method to completely wipe the cache, ensuring that no stale or outdated data remains. Logs these operations for visibility.
	public func resetCache(memory: Bool = true, disk: Bool = true) {
		cache.reset(memory: memory, disk: disk)
	}

	// MARK: - Network Handling
	public enum PollContinuation<T: Sendable>: Sendable {
		case finish(PollResult<T>)
		case `continue`(NetworkRequest, TimeInterval)
	}

	public typealias PollResult<T: Sendable> = Result<(EngineResponseHeader, T), Error>
	/// Immediately sends request, then can have a delay before repeating (or modifying) the request via the return value
	/// of the `until` block.
	///
	/// WIP - consider to be beta - interface is liable and LIKELY to change.
	@NHActor
	@discardableResult
	public func poll<T: Decodable>(
		request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		decoder: NHDecoder = GeneralEngineRequest.defaultDecoder,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		until: @escaping @NHActor (NetworkRequest, PollResult<T>) async throws(NetworkError) -> PollContinuation<T>
	) async throws -> (responseHeader: EngineResponseHeader, result: T) {
		func doPoll(request: NetworkRequest) async -> PollResult<T> {
			let polledResult: PollResult<T>
			do throws(NetworkError) {
				let (header, data) = try await transferMahDatas(
					for: request,
					delegate: delegate,
					usingCache: cacheOption,
					requestLogger: requestLogger,
					cancellationToken: cancellationToken)
				guard let data else { throw .noData }
				let decoded: T = try decodeData(data: data, using: decoder)
				polledResult = .success((header, decoded))
			} catch {
				polledResult = .failure(error)
			}
			return polledResult
		}

		let firstResult = await doPoll(request: request)

		var instruction = try await until(request, firstResult)

		while case .continue(let networkRequest, let timeInterval) = instruction {
			if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
				try await Task.sleep(for: .seconds(timeInterval))
			} else {
				try await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
			}
			let thisResult = await doPoll(request: networkRequest)
			instruction = try await until(networkRequest, thisResult)
		}

		guard case .finish(let result) = instruction else {
			throw NetworkError.unspecifiedError(reason: "Invalid State")
		}

		let finalResult = try result.get()

		return finalResult
	}

	/// Automatically decodes the data retrieved from the request to the generic, DecodableType.
	/// - Parameters:
	///   - request: NetworkRequest
	///   - delegate: Provides transfer lifecycle information
	///   - cacheOption:  NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not
	///   at all. **Default**: `.dontUseCache`
	///   - decoder: The decoder used to perform the decoding
	///   - requestLogger: Logger to use for this request
	///   - cancellationToken: Optional: Gives you the opportunity to create and hold a reference to a token
	///   allowing you to cancel the request before it completes.
	///   - onError: Error and retry handling
	/// - Returns: The response header from the server and the decoded body of the response.
	@NHActor
	@discardableResult public func downloadMahCodableDatas<DecodableType: Decodable>(
		for request: GeneralEngineRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		decoder: NHDecoder = GeneralEngineRequest.defaultDecoder,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, decoded: DecodableType) {
		let (header, rawData) = try await downloadMahDatas(
			for: request,
			delegate: delegate,
			usingCache: cacheOption,
			requestLogger: requestLogger,
			cancellationToken: cancellationToken,
			onError: onError)

		guard let rawData else { throw .noData }
		return try (header, decodeData(data: rawData, using: decoder))
	}

	/// Send a large blob to a server
	/// - Parameters:
	///   - request: UploadEngineRequest
	///   - payload: The file/data/stream you're uploading.
	///   - delegate: Provides transfer lifecycle information
	///   - requestLogger: Logger to use for this request
	///   - cancellationToken: Optional: Gives you the opportunity to create and hold a reference to a token
	///   allowing you to cancel the request before it completes.
	///   - onError: Error and retry handling
	/// - Returns: The response header from the server and the body of the response.
	@NHActor
	@discardableResult public func uploadMahDatas(
		for request: UploadEngineRequest,
		payload: UploadFile,
		delegate: NetworkHandlerTaskDelegate? = nil,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws -> (responseHeader: EngineResponseHeader, data: Data?) {
		try await transferMahDatas(
			for: .upload(request, payload: payload),
			delegate: delegate,
			usingCache: .dontUseCache,
			requestLogger: requestLogger,
			cancellationToken: cancellationToken,
			onError: onError)
	}
	
	/// Downloads remote data to a local file URL.
	/// - Parameters:
	///   - request: GeneralEngineRequest
	///   - outFileURL: The file URL to save the final data into (also used as the temporary file if none is explicitly specified)
	///   - tempoaryFileURL: The file URL to save file into as it's accumulated before the transfer is completed.
	///   - delegate: Provides transfer lifecycle information
	///   - cacheOption:  NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not
	///   at all. **Default**: `.dontUseCache`
	///   - requestLogger: Logger to use for this request
	///   - cancellationToken: Optional: Gives you the opportunity to create and hold a reference to a token
	///   allowing you to cancel the request before it completes.
	///   - onError: Error and retry handling
	/// - Returns: The response header from the server.
	@NHActor
	@discardableResult public func downloadMahFile(
		for request: GeneralEngineRequest,
		savingToLocalFileURL outFileURL: URL,
		withTemporaryFile tempoaryFileURL: URL? = nil,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> EngineResponseHeader {
		let tempFileURL = tempoaryFileURL ?? outFileURL

		guard
			tempFileURL.isFileURL,
			outFileURL.isFileURL
		else {
			throw NetworkError.unspecifiedError(reason: "Both the temporary url and output url must be local file URLs.")
		}

		if let cacheKey = cacheOption.cacheKey(url: request.url) {
			if let cachedData = cache[cacheKey] {
				try NetworkError.captureAndConvert {
					try cachedData.data.write(to: outFileURL)
				}
				return cachedData.response
			}
		}

		let (header, _) = try await retryHandler(
			originalRequest: .download(request),
			transferTask: { transferRequest, attempt in
				let (streamHeader, stream) = try await streamMahDatas(
					for: transferRequest,
					delegate: delegate,
					requestLogger: requestLogger,
					cancellationToken: cancellationToken)
				try? FileManager.default.removeItem(at: tempFileURL)

				try Data().write(to: tempFileURL)
				let fh = try FileHandle(forWritingTo: tempFileURL)

				for try await chunk in stream {
					try fh.write(contentsOf: chunk)
				}
				return (streamHeader, Data())
			},
			errorHandler: onError)
		if outFileURL.checkResourceIsAccessible() {
			var oldOut = outFileURL
			while oldOut.checkResourceIsAccessible() {
				let filename = oldOut.deletingPathExtension().lastPathComponent
				let newFilename = "\(filename).old"
				let ext = oldOut.pathExtension
				oldOut = oldOut
					.deletingLastPathComponent()
					.appending(component: newFilename)
					.appendingPathExtension(ext)
			}
			try NetworkError.captureAndConvert { try FileManager.default.moveItem(at: outFileURL, to: oldOut) }
		}
		try NetworkError.captureAndConvert { try FileManager.default.moveItem(at: tempFileURL, to: outFileURL) }

		if
			let cacheKey = cacheOption.cacheKey(url: request.url),
			let responseSize = header.expectedContentLength,
			responseSize < 1024 * 1024 * 100 {

			Task {
				let newlyCachedData = try Data(contentsOf: outFileURL)
				self.cache[cacheKey] = NetworkCacheItem(response: header, data: newlyCachedData)
			}
		}

		return header
	}

	/// Downloads data from a server. Also used to send smaller chunks of data, like REST requests, etc.
	/// - Parameters:
	///   - request: GeneralEngineRequest
	///   - delegate: Provides transfer lifecycle information
	///   - cacheOption:  NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not
	///   at all. **Default**: `.dontUseCache`
	///   - requestLogger: Logger to use for this request
	///   - onError: Error and retry handling
	/// - Returns: The response header from the server and the body of the response.
	@NHActor
	@discardableResult public func downloadMahDatas(
		for request: GeneralEngineRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, data: Data?) {
		try await transferMahDatas(
			for: .download(request),
			delegate: delegate,
			usingCache: cacheOption,
			requestLogger: requestLogger,
			cancellationToken: cancellationToken,
			onError: onError)
	}

	/// Downloads data from a server. Also used to send smaller chunks of data, like REST requests, etc.
	/// - Parameters:
	///   - request: NetworkRequest
	///   - delegate: Provides transfer lifecycle information
	///   - cacheOption:  NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not
	///   at all. **Default**: `.dontUseCache`
	///   - requestLogger: Logger to use for this request
	///   - cancellationToken: Optional: Gives you the opportunity to create and hold a reference to a token
	///   allowing you to cancel the request before it completes.
	///   - onError: Error and retry handling
	/// - Returns: The response header from the server and the body of the response.
	@NHActor
	@discardableResult public func transferMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, data: Data?) {
		if let cacheKey = cacheOption.cacheKey(url: request.url) {
			if let cachedData = cache[cacheKey] {
				return (cachedData.response, cachedData.data)
			}
		}

		let (header, data) = try await retryHandler(
			originalRequest: request,
			transferTask: { transferRequest, attempt in
				let (streamHeader, stream) = try await streamMahDatas(
					for: transferRequest,
					delegate: delegate,
					requestLogger: requestLogger,
					cancellationToken: cancellationToken)

				var accumulator = Data()
				for try await chunk in stream {
					accumulator.append(contentsOf: chunk)
				}
				return (streamHeader, accumulator)
			},
			errorHandler: onError)

		if let cacheKey = cacheOption.cacheKey(url: request.url), let data {
			self.cache[cacheKey] = NetworkCacheItem(response: header, data: data)
		}

		return (header, data)
	}
	
	/// Streams data from a server. Powers the rest of NetworkHandler.
	/// - Parameters:
	///   - request: NetworkRequest
	///   - delegate: Provides transfer lifecycle information
	///   - requestLogger: Logger to use for this request
	///   - cancellationToken: Optional: Gives you the opportunity to create and hold a reference to a token
	///   allowing you to cancel the request before it completes.
	/// - Returns: The response header from the server and a data stream that provides data as it is received.
	@NHActor
	@discardableResult public func streamMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, stream: ResponseBodyStream) {
		let (httpResponse, bodyResponseStream): (EngineResponseHeader, ResponseBodyStream)
		do {
			switch request {
			case .upload(var uploadRequest, let payload):
				let inputReq = uploadRequest
				uploadRequest = uploadRequest.with {
					switch payload {
					case .data(let data):
						$0.expectedContentLength = data.count
					case .localFile(let fileURL):
						$0.expectedContentLength = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
					case .inputStream(let stream):
						$0.expectedContentLength = (stream as? KnownLengthStream)?.totalStreamBytes
					}
				}
				if inputReq != uploadRequest {
					delegate?.requestModified(from: .upload(inputReq, payload: payload), to: .upload(uploadRequest, payload: payload))
				}

				try cancellationToken?.checkIsCancelled()
				let preEngineRequest = uploadRequest
				let (sendProgress, responseTask, bodyStream) = try await engine.uploadNetworkData(
					request: &uploadRequest,
					with: payload,
					requestLogger: requestLogger)
				cancellationToken?.onCancel = { bodyStream.cancel() }
				try cancellationToken?.checkIsCancelled()
				bodyStream.onFinish { reason in
					Task { // placed in another task to avoid lock-deadlock
						cancellationToken?.onCancel = {}
					}
				}
				if preEngineRequest != uploadRequest {
					delegate?.requestModified(from: .upload(preEngineRequest, payload: payload), to: .upload(uploadRequest, payload: payload))
				}

				async let progressBlock: Void = { @NHActor [delegate] in
					var signaledStart = false
					for try await count in sendProgress {
						if signaledStart == false {
							signaledStart = true
							delegate?.transferDidStart(for: request)
						}
						try Task.checkCancellation()
						delegate?.sentData(for: request, totalByteCountSent: Int(count), totalExpectedToSend: uploadRequest.expectedContentLength)
					}
				}()
				async let responseHeader = responseTask.value

				try await progressBlock
				httpResponse = try await responseHeader
				delegate?.responseHeaderRetrieved(for: request, header: httpResponse)
				bodyResponseStream = bodyStream
			case .download(let downloadRequest):
				try cancellationToken?.checkIsCancelled()
				let (header, bodyStream) = try await engine.fetchNetworkData(from: downloadRequest, requestLogger: requestLogger)
				cancellationToken?.onCancel = { bodyStream.cancel() }
				try cancellationToken?.checkIsCancelled()
				bodyStream.onFinish { reason in
					Task { // placed in another task to avoid lock-deadlock
						cancellationToken?.onCancel = {}
					}
				}

				delegate?.responseHeaderRetrieved(for: request, header: header)
				httpResponse = header
				let interceptedStream = ResponseBodyStream(errorOnCancellation: NetworkError.requestCancelled) { continuation in
					Task {
						var accumulatedBytes = 0
						do {
							for try await chunk in bodyStream {
								try continuation.yield(chunk)
								accumulatedBytes += chunk.count
								delegate?.responseBodyReceived(for: request, byteCount: accumulatedBytes, totalExpectedToReceive: header.expectedContentLength.map(Int.init))
								delegate?.responseBodyReceived(for: request, bytes: Data(chunk))
							}
							try continuation.finish()
							delegate?.requestFinished(withError: nil)
						} catch {
							try continuation.finish(throwing: error)
							delegate?.requestFinished(withError: error)
						}
					}
					continuation.onFinish { _ in bodyStream.cancel() }
				}
				bodyResponseStream = interceptedStream
			}
		} catch {
			throw NetworkError.convert(error)
		}

		guard request.expectedResponseCodes.rawValue.contains(httpResponse.status) else {
			logger.error("""
				Error: Server replied with unexpected status code: Got \(httpResponse.status) \
				expected \(request.expectedResponseCodes.rawValue)
				""")
			let data: Data? = await {
				var accumulator = Data()
				do {
					for try await bytes in bodyResponseStream {
						guard accumulator.count < 1024 * 1024 * 10 else { break }
						accumulator.append(contentsOf: bytes)
					}
				} catch {
					return accumulator.isOccupied ? accumulator : nil
				}
				return accumulator.isOccupied ? accumulator : nil
			}()
			throw NetworkError.httpUnexpectedStatusCode(code: httpResponse.status, originalRequest: request, data: data)
		}

		return (httpResponse, bodyResponseStream)
	}

	/// Internal retry loop. Evaluates conditions and output from `errorHandler` to determine what to try next.
	@NHActor
	private func retryHandler(
		originalRequest: NetworkRequest,
		transferTask: @NHActor (_ request: NetworkRequest, _ attempt: Int) async throws -> (EngineResponseHeader, Data?),
		errorHandler: RetryOptionBlock
	) async throws(NetworkError) -> (EngineResponseHeader, Data?) {
		var retryOption = RetryOption.retry
		var theRequest = originalRequest
		var attempt = 1

		while case .retryWithConfiguration = retryOption {
			defer { attempt += 1 }

			let theError: NetworkError
			do {
				return try await NetworkError.captureAndConvert {
					try await transferTask(theRequest, attempt)
				}
			} catch {
				theError = error
			}

			retryOption = errorHandler(theRequest, attempt, theError)
			switch retryOption {
			case .retryWithConfiguration(config: let config):
				theRequest = config.updatedRequest ?? theRequest

				if case .upload(let uploadReq, payload: let payload) = theRequest {
					switch payload {
					case .inputStream(let stream):
						guard let retryStream = stream as? RetryableStream else {
							logger.error("Streams cannot retry unless they conform to `RetryableStream`")
							throw theError
						}
						let newStream = try retryStream.copyWithRestart()
						theRequest = .upload(uploadReq, payload: .inputStream(newStream))
					default:
						break
					}
				}

				if config.delay > 0 {
					try await NetworkError.captureAndConvert {
						try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * config.delay))
					}
				}
			case .throw(updatedError: let updatedError):
				try NetworkError.captureAndConvert {
					throw updatedError ?? theError
				}
			case .defaultReturnValue(config: let returnConfig):
				let response: EngineResponseHeader
				switch returnConfig.response {
				case .full(let fullResponse):
					response = fullResponse
				case .code(let statusCode):
					response = EngineResponseHeader(status: statusCode, url: theRequest.url, headers: [:])
				}
				return (response, returnConfig.data)
			}
		}

		throw NetworkError.unspecifiedError(reason: "Escaped while loop")
	}

	private func decodeData<DecodableType: Decodable>(data: Data, using decoder: NHDecoder) throws(NetworkError) -> DecodableType {
		guard DecodableType.self != Data.self else {
			return data as! DecodableType // swiftlint:disable:this force_cast
		}

		do {
			let decodedValue = try decoder.decode(DecodableType.self, from: data)
			return decodedValue
		} catch {
			logger.error("Error: Couldn't decode \(DecodableType.self) from provided data (see thrown error)")
			throw NetworkError.dataCodingError(specifically: error, sourceData: data)
		}
	}

	public enum CacheKeyOption:
		Equatable,
		ExpressibleByBooleanLiteral,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

		case dontUseCache
		case useURL
		case key(String)

		public init(booleanLiteral value: BooleanLiteralType) {
			self = value ? .useURL : .dontUseCache
		}

		public init(stringLiteral value: StringLiteralType) {
			self = .key(value)
		}

		func cacheKey(url: URL?) -> String? {
			switch self {
			case .dontUseCache:
				return nil
			case .useURL:
				return url?.absoluteString
			case .key(let value):
				return value
			}
		}
	}
}
