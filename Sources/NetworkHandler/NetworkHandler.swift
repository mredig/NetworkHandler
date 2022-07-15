//swiftlint:disable line_length

import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif

public class NetworkHandler {
	// MARK: - Properties
	public var printErrorsToConsole = false

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
				printToConsole("Error: Couldn't decode \(DecodableType.self) from provided data (see thrown error)")
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
		sessionConfiguration: URLSessionConfiguration? = nil) async throws -> (data: Data, response: URLResponse) {
			if let cacheKey = cacheOption.cacheKey(url: request.url) {
				if let cachedData = cache[cacheKey] {
					return (cachedData.data, cachedData.response)
				}
			}

			let session = sessionConfiguration
				.map { URLSession(configuration: $0, delegate: sessionDelegate, delegateQueue: delegateQueue) }
				?? defaultSession

			let task: URLSessionTask
			switch request.payload {
			case .upload(let uploadFile):
				switch uploadFile {
				case .data(let data):
					task = session.uploadTask(with: request.urlRequest, from: data)
				case .localFile(let localFileURL):
					task = session.uploadTask(with: request.urlRequest, fromFile: localFileURL)
				}
			default:
				task = session.dataTask(with: request.urlRequest)
			}
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
			let progressObserver = task.progress.observe(\.fractionCompleted, options: .new) { progress, _ in
				OperationQueue.main.addOperation {
					delegate?.networkHandlerTask(task, didProgress: task.progress.fractionCompleted)
				}
			}

			let publisher = sessionDelegate.publisher(for: task)

			let data: Data
			do {
				data = try await withTaskCancellationHandler(
					operation: {
						try Task.checkCancellation()
						guard
							task.state == .suspended ||
								task.state == .running
						else {
							sessionDelegate.cancelTracking(for: task)
							throw NetworkError.requestCancelled
						}
						return try await withCheckedThrowingContinuation({ continuation in
							var totalData = Data()
							publisher
								.sink(
									receiveValue: {
										totalData.append($0)
									},
									receiveCompletion: { completionInfo in
										switch completionInfo {
										case .finished:
											continuation.resume(returning: totalData)
										case .failure(let error):
											continuation.resume(throwing: error)
										}
									})

							task.resume()
						})
					},
					onCancel: {
						task.cancel()
					})
			} catch {
				let error = error as NSError
				if
					error.domain == NSURLErrorDomain,
					error.code == NSURLErrorCancelled {
					throw NetworkError.requestCancelled
				} else {
					throw error
				}
			}

			stateObserver.invalidate()
			progressObserver.invalidate()

			guard let httpResponse = task.response as? HTTPURLResponse else {
				printToConsole("Error: Server replied with no status code")
				throw NetworkError.noStatusCodeResponse
			}
			guard request.expectedResponseCodes.contains(httpResponse.statusCode) else {
				printToConsole("Error: Server replied with expected status code: Got \(httpResponse.statusCode) expected \(request.expectedResponseCodes)")
				throw NetworkError.httpNon200StatusCode(code: httpResponse.statusCode, data: data)
			}

			if let cacheKey = cacheOption.cacheKey(url: request.url) {
				self.cache[cacheKey] = NetworkCacheItem(response: httpResponse, data: data)
			}

			return (data, httpResponse)
		}

	private func printToConsole(_ string: String) {
		if printErrorsToConsole {
			print(string)
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
