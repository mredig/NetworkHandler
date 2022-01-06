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
	public var defaultSession: URLSession = {
		let config = URLSessionConfiguration.default
		config.requestCachePolicy = .reloadIgnoringLocalCacheData
		config.urlCache = nil
		return URLSession(configuration: config)
	}()

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init(name: String, diskCacheCapacity: UInt64 = .max) {
		self.name = name
		self.cache = NetworkCache(name: "\(name)-Cache", diskCacheCapacity: diskCacheCapacity)
	}

	// MARK: - Network Handling
	/**
	Preconfigured URLSession tasking to fetch and decode decodable data.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- delegate: URLSessionTaskDelegate for life cycle and authentication challenge callbacks as the transfer progresses. (Does not receive progress updates)
		**Default**: `nil`
		- cacheOption: NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not at all. **Default**: `.dontUseCache`
		- session: URLSession instance. **Default**: `self.defaultSession`
	- Returns: The resulting, decoded data safely typed as the `DecodableType` and the `URLResponse` from the task
	*/
	@discardableResult public func transferMahCodableDatas<DecodableType: Decodable>(
		for request: NetworkRequest,
		with delegate: URLSessionTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		session: URLSession? = nil) async throws -> (decoded: DecodableType, response: URLResponse) {
			let totalResponse = try await transferMyDatas(for: request, with: delegate, usingCache: cacheOption, session: session)

			let decoder = request.decoder
			let decodedValue = try decoder.decode(DecodableType.self, from: totalResponse.data)
			return (decodedValue, totalResponse.response)
		}

	/**
	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- delegate: URLSessionTaskDelegate for life cycle and authentication challenge callbacks as the transfer progresses. (Does not receive progress updates)
		**Default**: `nil`
		- cacheOption: NetworkHandler.CacheKeyOption indicating whether to use cache with or without a key overrride or not at all. **Default**: `.dontUseCache`
		- session: URLSession instance. **Default**: `self.defaultSession`
	 - Returns: The resulting,  raw data typed as `Data` and the `URLResponse` from the task

	 Note that delegate is only valid in iOS 15, macOS 12, tvOS 15, and watchOS 8 and higher
	*/
	@discardableResult public func transferMyDatas(
		for request: NetworkRequest,
		with delegate: URLSessionTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		session: URLSession? = nil) async throws -> (data: Data, response: URLResponse) {
			if let cacheKey = cacheOption.cacheKey(url: request.url) {
				if let cachedData = cache[cacheKey] {
					return (cachedData.data, cachedData.response)
				}
			}

			let session = session ?? defaultSession

			let totalResponse: (data: Data, response: URLResponse)
			if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
				totalResponse = try await session.data(for: request.urlRequest, delegate: delegate)
			} else {
				totalResponse = try await withCheckedThrowingContinuation({ continuation in
					let task = session.dataTask(with: request.urlRequest) { data, response, error in
						if let error = error {
							continuation.resume(throwing: error)
							return
						}

						let data = data ?? Data()

						guard let response = response else {
							continuation.resume(throwing: NetworkError.noURLResponse)
							return
						}

						continuation.resume(returning: (data, response))
					}
					task.resume()
				})
			}

			guard let httpResponse = totalResponse.response as? HTTPURLResponse else {
				throw NetworkError.noStatusCodeResponse
			}
			guard request.expectedResponseCodes.contains(httpResponse.statusCode) else {
				throw NetworkError.httpNon200StatusCode(code: httpResponse.statusCode, data: totalResponse.data)
			}

			if let cacheKey = cacheOption.cacheKey(url: request.url) {
				self.cache[cacheKey] = NetworkCacheItem(response: totalResponse.response, data: totalResponse.data)
			}

			return totalResponse
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
