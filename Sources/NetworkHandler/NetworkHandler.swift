//swiftlint:disable line_length

import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif
import SaferContinuation
import Swiftwood

public class NetworkHandler {
	// MARK: - Properties
	@available(*, deprecated, message: "Use `enableLogging`")
	public var printErrorsToConsole: Bool {
		get { enableLogging }
		set { enableLogging = newValue }
	}
	public var enableLogging = false {
		didSet {
			guard enableLogging else { return }
			setupLogging()
		}
	}

	/**
	An instance of Network Cache to speed up subsequent requests. Usage is
	optional, but automatic when making requests using the `usingCache` flag.
	*/
	let cache: NetworkCache

	public let name: String

	/// A default instance of NetworkHandler provided for convenience. Use is optional.
	public static let `default` = NetworkHandler(name: "NHDefault", diskCacheCapacity: .max)

	/// Defaults to a `URLSession` with a default `URLSessionConfiguration`, minus the `URLCache` since caching is handled via `NetworkCache`
	public let defaultSession: URLSession
	private let nhMainUploadDelegate: NHUploadDelegate
	private let delegateQueue: OperationQueue = {
		let q = OperationQueue()
		q.maxConcurrentOperationCount = 1
		return q
	}()

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init(name: String, diskCacheCapacity: UInt64 = .max, configuration: URLSessionConfiguration? = nil) {
		self.name = name
		self.cache = NetworkCache(name: "\(name)-Cache", diskCacheCapacity: diskCacheCapacity)

		let config = configuration ?? .networkHandlerDefault

		let uploadDelegate = NHUploadDelegate()
		self.nhMainUploadDelegate = uploadDelegate
		self.defaultSession = URLSession(configuration: config, delegate: uploadDelegate, delegateQueue: delegateQueue)

		_ = URLSessionTask.swizzleSetState
	}

	deinit {
		defaultSession.finishTasksAndInvalidate()
	}

	public func resetCache(memory: Bool = true, disk: Bool = true) {
		cache.reset(memory: memory, disk: disk)
	}

	// MARK: - Network Handling
	public enum PollContinuation<T> {
		case finish(PollResult<T>)
		case `continue`(NetworkRequest, TimeInterval)
	}

	public typealias PollResult<T> = Result<(T, HTTPURLResponse), Error>
	/// Immediately sends request, then can have a delay before repeating (or modifying) the request via the return value of the `until` block.
	///
	/// WIP - consider to be beta - interface is liable and LIKELY to change.
	@NHActor
	@discardableResult
	public func poll<T>(
		request: NetworkRequest,
		delegate: NetworkHandlerTransferDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		sessionConfiguration: URLSessionConfiguration? = nil,
		until: @escaping @NHActor (NetworkRequest, PollResult<Data>) async throws -> PollContinuation<T>
	) async throws -> (result: T, response: HTTPURLResponse) {
		func doPoll(request: NetworkRequest) async -> PollResult<Data> {
			let polledResult: PollResult<Data>
			do {
				let result = try await transferMahDatas(
					for: request,
					delegate: delegate,
					usingCache: cacheOption,
					sessionConfiguration: sessionConfiguration)
				polledResult = .success(result)
			} catch {
				polledResult = .failure(error)
			}
			return polledResult
		}

		let firstResult = await doPoll(request: request)
		
		var instruction = try await until(request, firstResult)

		while case .continue(let networkRequest, let timeInterval) = instruction {
			if #available(macOS 13.0, *) {
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
		- cacheOption: NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not at all. **Default**: `.dontUseCache`
		- session: URLSession instance. **Default**: `self.defaultSession`
	- Returns: The resulting, decoded data safely typed as the `DecodableType` and the `URLResponse` from the task
	*/
	@NHActor
	@discardableResult public func transferMahCodableDatas<DecodableType: Decodable>(
		for request: NetworkRequest,
		delegate: NetworkHandlerTransferDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		sessionConfiguration: URLSessionConfiguration? = nil) async throws -> (decoded: DecodableType, response: HTTPURLResponse) {
			let totalResponse = try await transferMahDatas(for: request, delegate: delegate, usingCache: cacheOption, sessionConfiguration: sessionConfiguration)

			guard DecodableType.self != Data.self else {
				return (totalResponse.data as! DecodableType, totalResponse.response)
			}

			let decoder = request.decoder
			do {
				let decodedValue = try decoder.decode(DecodableType.self, from: totalResponse.data)
				return (decodedValue, totalResponse.response)
			} catch {
				logIfEnabled("Error: Couldn't decode \(DecodableType.self) from provided data (see thrown error)", logLevel: .error)
				throw NetworkError.dataCodingError(specifically: error, sourceData: totalResponse.data)
			}
		}

	/**
	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- cacheOption: NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not at all. **Default**: `.dontUseCache`
		- session: URLSession instance. **Default**: `self.defaultSession`
	 - Returns: The resulting,  raw data typed as `Data` and the `URLResponse` from the task

	 Note that delegate is only valid in iOS 15, macOS 12, tvOS 15, and watchOS 8 and higher
	*/
	@NHActor
	@discardableResult public func transferMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTransferDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		sessionConfiguration: URLSessionConfiguration? = nil,
		onError: @escaping (NetworkRequest, Int, NetworkError) -> RetryOption = { _, _, _ in .throw }
	) async throws -> (data: Data, response: HTTPURLResponse) {
		var retryOption = RetryOption.retry
		var theRequest = request
		var attempt = 1

		while case .retryWithConfiguration = retryOption {
			defer { attempt += 1 }

			let theError: NetworkError
			do {
				return try await _transferMahDatas(
					for: theRequest,
					delegate: delegate,
					usingCache: cacheOption,
					attempt: attempt,
					sessionConfiguration: sessionConfiguration)
			} catch let error as NetworkError {
				theError = error
			} catch {
				theError = .otherError(error: error)
			}

			retryOption = onError(theRequest, attempt, theError)
			switch retryOption {
			case .retryWithConfiguration(config: let config):
				theRequest = config.updatedRequest ?? theRequest
				if config.delay > 0 {
					try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * config .delay))
				}
			case .throw(updatedError: let updatedError):
				throw updatedError ?? theError
			case .defaultReturnValue(config: let returnConfig):
				let response: HTTPURLResponse
				switch returnConfig.response {
				case .full(let fullResponse):
					response = fullResponse
				case .code(let statusCode):
					response = HTTPURLResponse(
						url: theRequest.url!,
						statusCode: statusCode,
						httpVersion: nil,
						headerFields: [
							"Content-Length": "\(returnConfig.data.count)",
						])!
				}
				return (returnConfig.data, response)
			}
		}

		throw NetworkError.unspecifiedError(reason: "Escaped while loop")
	}

	public struct RetryConfiguration {
		public static let retry = RetryConfiguration(delay: 0)

		public var delay: TimeInterval
		public var updatedRequest: NetworkRequest?

		public init(
			delay: TimeInterval,
			updatedRequest: NetworkRequest? = nil
		) {
			self.delay = delay
			self.updatedRequest = updatedRequest
		}
	}

	public struct DefaultReturnValueConfiguration {
		public var data: Data
		public var response: ResponseOption

		public enum ResponseOption {
			case full(HTTPURLResponse)
			case code(Int)
		}
	}

	public enum RetryOption {
		public static let retry = RetryOption.retryWithConfiguration(config: .retry)
		case retryWithConfiguration(config: RetryConfiguration)
		public static func retry(
			withDelay delay: TimeInterval = 0,
			updatedRequest: NetworkRequest? = nil
		) -> RetryOption {
			let config = RetryConfiguration(delay: delay, updatedRequest: updatedRequest)
			return .retryWithConfiguration(config: config)
		}

		case `throw`(updatedError: Error?)
		public static let `throw` = RetryOption.throw(updatedError: nil)
		case defaultReturnValue(config: DefaultReturnValueConfiguration)

		public static func defaultReturnValue(data: Data, statusCode: Int) -> RetryOption {
			let config = DefaultReturnValueConfiguration(data: data, response: .code(statusCode))
			return .defaultReturnValue(config: config)
		}

		public static func defaultReturnValue(data: Data, urlResponse: HTTPURLResponse) -> RetryOption {
			let config = DefaultReturnValueConfiguration(data: data, response: .full(urlResponse))
			return .defaultReturnValue(config: config)
		}
	}

	@NHActor
	@discardableResult private func _transferMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTransferDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		attempt: Int,
		sessionConfiguration: URLSessionConfiguration? = nil
	) async throws -> (data: Data, response: HTTPURLResponse) {
		if let cacheKey = cacheOption.cacheKey(url: request.url) {
			if let cachedData = cache[cacheKey] {
				return (cachedData.data, cachedData.response)
			}
		}

		let session = sessionConfiguration
			.map { URLSession(configuration: $0, delegate: nhMainUploadDelegate, delegateQueue: delegateQueue) }
		?? defaultSession

		defer {
			if session !== defaultSession {
				session.finishTasksAndInvalidate()
			}
		}

		let (data, httpResponse): (Data, HTTPURLResponse)
		do {
			switch request.payload {
			case .upload(let uploadFile):
				(data, httpResponse) = try await uploadTask(session: session, request: request, uploadFile: uploadFile, delegate: delegate)
			default:
				(data, httpResponse) = try await downloadTask(session: session, request: request, delegate: delegate)
			}
		} catch {
			let error = error as NSError
			if
				error.domain == NSURLErrorDomain,
				error.code == NSURLErrorCancelled {
				throw NetworkError.requestCancelled
			} else if (error as? CancellationError) != nil {
				throw NetworkError.requestCancelled
			} else {
				throw error
			}
		}

		guard request.expectedResponseCodes.contains(httpResponse.statusCode) else {
			logIfEnabled("Error: Server replied with expected status code: Got \(httpResponse.statusCode) expected \(request.expectedResponseCodes)", logLevel: .error)
			throw NetworkError.httpNon200StatusCode(code: httpResponse.statusCode, data: data)
		}

		if let cacheKey = cacheOption.cacheKey(url: request.url) {
			self.cache[cacheKey] = NetworkCacheItem(response: httpResponse, data: data)
		}

		return (data, httpResponse)
	}

	private func downloadTask(session: URLSession, request: NetworkRequest, delegate: NetworkHandlerTransferDelegate?) async throws -> (Data, HTTPURLResponse) {
		let (asyncBytes, response) = try await session.bytes(for: request.urlRequest, delegate: delegate)
		let task = asyncBytes.task
		task.priority = request.priority.rawValue
		delegate?.task = task

		guard let httpResponse = response as? HTTPURLResponse else {
			logIfEnabled("Error: Server replied with no status code", logLevel: .error)
			throw NetworkError.noStatusCodeResponse
		}

		if let delegate {
			await MainActor.run {
				delegate.networkHandlerTaskDidStart(task)
			}
		}

		return try await withTaskCancellationHandler(operation: {
			var data = Data()
			data.reserveCapacity(Int(httpResponse.expectedContentLength))
			var lastUpdate = Date.distantPast
			var count = 0
			for try await byte in asyncBytes {
				data.append(byte)
				count += 1

				let now = Date()
				if now > lastUpdate.addingTimeInterval(1 / 30) {
					lastUpdate = now

					delegate?.networkHandlerTask(task, didProgress: Double(count) / Double(httpResponse.expectedContentLength))
				}
			}

			return (data, httpResponse)
		}, onCancel: { [weak task] in
			task?.cancel()
		})
	}

	private func uploadTask(session: URLSession, request: NetworkRequest, uploadFile: NetworkRequest.UploadFile, delegate: NetworkHandlerTransferDelegate?) async throws -> (Data, HTTPURLResponse) {
		var taskHolder: URLSessionTask?

		return try await withTaskCancellationHandler(
			operation: {
				let data: Data
				let task: URLSessionUploadTask
				switch uploadFile {
				case .localFile(let url):
					task = session.uploadTask(with: request.urlRequest, fromFile: url)
				case .data(let uploadData):
					task = session.uploadTask(with: request.urlRequest, from: uploadData)
				}

				if let delegate {
					nhMainUploadDelegate.addTaskDelegate(delegate, for: task)
				}
				taskHolder = task

				data = try await withCheckedThrowingContinuation({ continuation in
					let safer = SaferContinuation(
						continuation,
						isFatal: [.onMultipleCompletions, .onPostRunDelayCheck],
						timeout: request.timeoutInterval * 1.5,
						delayCheckInterval: 3,
						context: "(\(request.httpMethod as Any)): \(request.url as Any)")

					var dataAccumulator = Data()

					nhMainUploadDelegate
						.taskKeepalivePublisher(for: task)
						.sink(receiveValue: {
							safer.keepAlive()
						})

					nhMainUploadDelegate
						.dataPublisher(for: task)
						.sink(
							receiveValue: { data in
								dataAccumulator.append(contentsOf: data)
								safer.keepAlive()
							},
							receiveCompletion: { completion in
								switch completion {
								case .finished:
									safer.resume(returning: dataAccumulator)
								case .failure(let error):
									safer.resume(throwing: error)
								}
							})

					task.resume()

					DispatchQueue.main.async {
						delegate?.networkHandlerTaskDidStart(task)
					}
				})

				guard let response = task.response else {
					logIfEnabled("Error no response provided", logLevel: .error)
					throw NetworkError.noURLResponse
				}
				guard let httpResponse = response as? HTTPURLResponse else {
					logIfEnabled("Error: Server replied with no status code", logLevel: .error)
					throw NetworkError.noStatusCodeResponse
				}

				return (data, httpResponse)
			},
			onCancel: { [weak taskHolder] in
				taskHolder?.cancel()
			})
	}

	private func logIfEnabled(_ string: String, logLevel: Swiftwood.Level) {
		if enableLogging {
			log.custom(level: logLevel, string)
		}
	}

	public enum CacheKeyOption: Equatable, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
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
