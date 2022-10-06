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
	private let sessionDelegate: TheDelegate
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

		let sessionDelegate = TheDelegate()

		self.defaultSession = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: delegateQueue)
		self.sessionDelegate = sessionDelegate
	}

	public func resetCache(memory: Bool = true, disk: Bool = true) {
		cache.reset(memory: memory, disk: disk)
	}

	// MARK: - Network Handling
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
		sessionConfiguration: URLSessionConfiguration? = nil) async throws -> (decoded: DecodableType, response: URLResponse) {
			let totalResponse = try await transferMahDatas(for: request, delegate: delegate, usingCache: cacheOption, sessionConfiguration: sessionConfiguration)

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
		sessionConfiguration: URLSessionConfiguration? = nil) async throws -> (data: Data, response: HTTPURLResponse) {
			if let cacheKey = cacheOption.cacheKey(url: request.url) {
				if let cachedData = cache[cacheKey] {
					return (cachedData.data, cachedData.response)
				}
			}

			let session = sessionConfiguration
				.map { URLSession(configuration: $0, delegate: sessionDelegate, delegateQueue: delegateQueue) }
				?? defaultSession

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
		let (asyncBytes, response) = try await session.bytes(for: request.urlRequest)

		guard let httpResponse = response as? HTTPURLResponse else {
			logIfEnabled("Error: Server replied with no status code", logLevel: .error)
			throw NetworkError.noStatusCodeResponse
		}

		let task = asyncBytes.task
		OperationQueue.main.addOperationAndWaitUntilFinished {
			delegate?.networkHandlerTaskDidStart(task)
			delegate?.networkHandlerTask(task, stateChanged: task.state)
		}

		task.priority = request.priority.rawValue

		let stateObserver = task.observe(\.state, options: [.new]) { task, _ in
			OperationQueue.main.addOperation {
				delegate?.networkHandlerTask(task, stateChanged: task.state)
			}
		}

		defer { stateObserver.invalidate() }

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
		}, onCancel: { [weak stateObserver, weak task] in
			task?.cancel()
			stateObserver?.invalidate()
		})
	}

	private func uploadTask(session: URLSession, request: NetworkRequest, uploadFile: NetworkRequest.UploadFile, delegate: NetworkHandlerTransferDelegate?) async throws -> (Data, HTTPURLResponse) {
		let uploadDelegate = UploadDelegate(delegate: delegate, request: request)

		return try await withTaskCancellationHandler(
			operation: {
				let (data, response): (Data, URLResponse)
				switch uploadFile {
				case .localFile(let url):
					(data, response) = try await session.upload(for: request.urlRequest, fromFile: url, delegate: uploadDelegate)
				case .data(let uploadData):
					(data, response) = try await session.upload(for: request.urlRequest, from: uploadData, delegate: uploadDelegate)
				}

				guard let httpResponse = response as? HTTPURLResponse else {
					logIfEnabled("Error: Server replied with no status code", logLevel: .error)
					throw NetworkError.noStatusCodeResponse
				}

				return (data, httpResponse)
			},
			onCancel: { [weak uploadDelegate] in
				uploadDelegate?.task?.cancel()
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
