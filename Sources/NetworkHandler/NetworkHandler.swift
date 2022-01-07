//swiftlint:disable line_length

import Combine
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

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init(name: String, diskCacheCapacity: UInt64 = .max, configuration: URLSessionConfiguration? = nil) {
		self.name = name
		self.cache = NetworkCache(name: "\(name)-Cache", diskCacheCapacity: diskCacheCapacity)

		let config = configuration ?? {
			let c = URLSessionConfiguration.default
			c.requestCachePolicy = .reloadIgnoringLocalCacheData
			c.urlCache = nil
			return c
		}()

		let sessionDelegate = TheDelegate()

		self.defaultSession = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
		self.sessionDelegate = sessionDelegate
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
	@discardableResult public func transferMahCodableDatas<DecodableType: Decodable>(
		for request: NetworkRequest,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		session: URLSession? = nil) async throws -> (decoded: DecodableType, response: URLResponse) {
			let totalResponse = try await transferMahDatas(for: request, usingCache: cacheOption, session: session)

			let decoder = request.decoder
			do {
				let decodedValue = try decoder.decode(DecodableType.self, from: totalResponse.data)
				return (decodedValue, totalResponse.response)
			} catch {
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
	@discardableResult public func transferMahDatas(
		for request: NetworkRequest,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		session: URLSession? = nil) async throws -> (data: Data, response: URLResponse) {
			if let cacheKey = cacheOption.cacheKey(url: request.url) {
				if let cachedData = cache[cacheKey] {
					return (cachedData.data, cachedData.response)
				}
			}

//			let session = session ?? defaultSession
			let session = defaultSession

			let task = session.dataTask(with: request.urlRequest)

			let publisher = sessionDelegate.publisher(for: task)

			var bag: Set<AnyCancellable> = []
			let data: Data = try await withCheckedThrowingContinuation({ continuation in
				var totalData = Data()
				publisher
					.sink(
						receiveCompletion: { completionInfo in
							switch completionInfo {
							case .finished:
								continuation.resume(returning: totalData)
							case .failure(let error):
								continuation.resume(throwing: error)
							}
						},
						receiveValue: {
							totalData.append($0)
						})
					.store(in: &bag)

				task.resume()
			})

			guard let httpResponse = task.response as? HTTPURLResponse else {
				throw NetworkError.noStatusCodeResponse
			}
			guard request.expectedResponseCodes.contains(httpResponse.statusCode) else {
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
