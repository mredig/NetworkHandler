import Foundation
@_exported import NetworkHalpers
import SwiftPizzaSnips
#if canImport(FoundationNetworking)
import FoundationNetworking
import NHLinuxSupport
#endif
import SaferContinuation
import Swiftwood

public typealias NHCodedResponse<T: Decodable> = (decoded: T, response: HTTPURLResponse)

public class NetworkHandler<Engine: NetworkEngine> {
	public typealias NHRawResponse = (data: Engine.ResponseBodyStream, response: EngineResponseHeader)
	// MARK: - Properties
	public var enableLogging = false {
		didSet {
			guard enableLogging else { return }
			// FIXME: DO logging
			setupLogging()
		}
	}

	/**
	 An instance of Network Cache to speed up subsequent requests. Usage is
	 optional, but automatic when making requests using the `usingCache` flag.
	 */
	let cache: NetworkCache

	public let name: String

	/// Underlying engine running network transactions
	public let engine: Engine

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init(name: String, engine: Engine, diskCacheCapacity: UInt64 = .max) {
		self.name = name
		self.cache = NetworkCache(name: "\(name)-Cache", diskCacheCapacity: diskCacheCapacity)

		self.engine = engine
	}

	deinit {
		engine.shutdown()
	}

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
		decoder: NHDecoder = DownloadEngineRequest.defaultDecoder,
		until: @escaping @NHActor (NetworkRequest, PollResult<T>) async throws -> PollContinuation<T>
	) async throws -> (responseHeader: EngineResponseHeader, result: T) {
		func doPoll(request: NetworkRequest) async -> PollResult<T> {
			let polledResult: PollResult<T>
			do {
				let (header, data) = try await transferMahDatas(
					for: request,
					delegate: delegate,
					usingCache: cacheOption)
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

	/**
	 Preconfigured URLSession tasking to fetch and decode decodable data.

	 - Parameters:
	 - request: NetworkRequest containing the url and other request information.
	 - cacheOption: NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not
	 at all. **Default**: `.dontUseCache`
	 - Returns: The resulting, decoded data safely typed as the `DecodableType` and the `URLResponse` from the task
	 */
	@NHActor
	@discardableResult public func transferMahCodableDatas<DecodableType: Decodable>(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		decoder: NHDecoder = DownloadEngineRequest.defaultDecoder,
		onError: @escaping RetryOptionBlock<Data> = { _, _, _ in .throw }
	) async throws -> (responseHeader: EngineResponseHeader, decoded: DecodableType) {
		let (header, rawData) = try await transferMahDatas(
			for: request,
			delegate: delegate,
			usingCache: cacheOption,
			onError: onError)

		return try (header, decodeData(data: rawData, using: decoder))
	}

	/**
	 - Parameters:
	 - request: NetworkRequest containing the url and other request information.
	 - cacheOption: NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not
	 at all. **Default**: `.dontUseCache`
	 - Returns: The resulting,  raw data typed as `Data` and the `URLResponse` from the task

	 Note that delegate is only valid in iOS 15, macOS 12, tvOS 15, and watchOS 8 and higher
	 */
	@NHActor
	@discardableResult public func transferMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		onError: @escaping RetryOptionBlock<Data> = { _, _, _ in .throw }
	) async throws -> (responseHeader: EngineResponseHeader, data: Data) {
		// FIXME: Do cache option

		try await retryHandler(
			originalRequest: request,
			transferTask: { transferRequest, attempt in
				let (streamHeader, stream) = try await streamMahDatas(for: transferRequest, delegate: delegate)

				var accumulator = Data()
				for try await chunk in stream {
					accumulator.append(contentsOf: chunk)
				}
				return (streamHeader, accumulator)
			},
			errorHandler: onError)
	}

	@NHActor
	@discardableResult public func streamMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil
	) async throws -> (responseHeader: EngineResponseHeader, stream: Engine.ResponseBodyStream) {
		let (httpResponse, bodyResponseStream): (EngineResponseHeader, Engine.ResponseBodyStream)
		do {
			switch request {
			case .upload(let uploadRequest, let payload):
				let (sendProgress, responseTask, bodyStream) = try await engine.uploadNetworkData(request: uploadRequest, with: payload)
				async let progressBlock: Void = { @NHActor in
					var signaledStart = false
					for try await count in sendProgress {
						if signaledStart == false {
							signaledStart = true
							delegate?.transferDidStart(for: request)
						}
						delegate?.sentData(for: request, byteCountSent: Int(count), totalExpectedToSend: nil)
					}
				}()
				async let responseHeader = responseTask.value

				try await progressBlock
				httpResponse = try await responseHeader
				delegate?.responseHeaderRetrieved(for: request, header: httpResponse)
				bodyResponseStream = bodyStream
			case .download(let downloadRequest):
				let (header, bodyStream) = try await engine.fetchNetworkData(from: downloadRequest)
				httpResponse = header
				bodyResponseStream = bodyStream
			}
		} catch {
			throw error.convertToNetworkErrorIfCancellation()
		}

		guard request.expectedResponseCodes.rawValue.contains(httpResponse.status) else {
			logIfEnabled(
				"""
				Error: Server replied with expected status code: Got \(httpResponse.status) \
				expected \(request.expectedResponseCodes)
				""",
				logLevel: .error)
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

	private func retryHandler<T>(
		originalRequest: NetworkRequest,
		transferTask: (_ request: NetworkRequest, _ attempt: Int) async throws -> (EngineResponseHeader, T),
		errorHandler: RetryOptionBlock<T>
	) async throws -> (EngineResponseHeader, T) {
		var retryOption = RetryOption<T>.retry
		var theRequest = originalRequest
		var attempt = 1

		while case .retryWithConfiguration = retryOption {
			defer { attempt += 1 }

			let theError: NetworkError
			do {
				return try await transferTask(theRequest, attempt)
			} catch let error as NetworkError {
				theError = error
			} catch {
				theError = .otherError(error: error)
			}

			retryOption = errorHandler(theRequest, attempt, theError)
			switch retryOption {
			case .retryWithConfiguration(config: let config):
				theRequest = config.updatedRequest ?? theRequest
				if config.delay > 0 {
					try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * config .delay))
				}
			case .throw(updatedError: let updatedError):
				throw updatedError ?? theError
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

	private func decodeData<DecodableType: Decodable>(data: Data, using decoder: NHDecoder) throws -> DecodableType {
		guard DecodableType.self != Data.self else {
			return data as! DecodableType // swiftlint:disable:this force_cast
		}

		do {
			let decodedValue = try decoder.decode(DecodableType.self, from: data)
			return decodedValue
		} catch {
			logIfEnabled(
				"Error: Couldn't decode \(DecodableType.self) from provided data (see thrown error)",
				logLevel: .error)
			throw NetworkError.dataCodingError(specifically: error, sourceData: data)
		}
	}

	private func logIfEnabled(_ string: String, logLevel: Swiftwood.Level) {
		if enableLogging {
			log.custom(level: logLevel, string)
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

//extension AsyncCancellableThrowingStream {
//	static func data(_ data: Data, chunkSize: Int = 1024 * 1024 * 4) -> AsyncCancellableThrowingStream<[UInt8], Error> {
//		AsyncCancellableThrowingStream<[UInt8], Error> { continuation in
//			var lastOffset = 0
//			for offset in stride(from: data.startIndex, through: data.endIndex, by: chunkSize) {
//				defer { lastOffset = offset }
//				guard
//					(lastOffset..<offset).isOccupied
//				else { continue }
//				try! continuation.yield(Array(data[lastOffset..<offset]))
//			}
//			if lastOffset < data.endIndex {
//				try! continuation.yield(Array(data[lastOffset..<data.endIndex]))
//			}
//			try? continuation.finish()
//		}
//	}
//}
