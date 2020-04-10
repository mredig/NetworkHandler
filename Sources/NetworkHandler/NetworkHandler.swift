//
//  NetworkHandler.swift
//
//  Created by Michael Redig on 5/7/19.
//  Copyright © 2019 Michael Redig. All rights reserved.
//
//swiftlint:disable line_length

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public class NetworkHandler {
	// MARK: - Properties
	public var printErrorsToConsole = false

	/// When querying for Codable data, if the response received is `null` (typically in the event that a remote object
	/// doesn't exist - This ocurrs on firebase for example) consider it valid as an empty collection. Only works on
	/// types that conform to Sequence.
	public var nullDataIsValid = false

	/// Set this value to `true` when dealing with a graphQL server as they return a `200` response code even in error
	/// states, but with different (error) json model. Turning this on will then attempt to decode the json error model
	/// and pass forward the errors provided by the graphQL server.
	public var graphQLErrorSupport = false

	/**
	An instance of Network Cache to speed up subsequent requests. Usage is
	optional, but automatic when making requests using the `usingCache` flag.

	Note that URLCache is still used behind the scenes for requests that don't have
	the `usingCache` flag toggled true. This means that you can modify and have the
	current level of support by using the URLRequest's `cachePolicy` property for
	requests that don't have `usingCache` true. However, when `usingCache` is
	toggled true, local and remote cache policy headers are ignored and the data is
	stored indefinitely (until it either gets deleted to make space for more recent
	cache objects or the app is closed), ready to be reloaded instantly the next
	time a duplicate URL request is made (Note that it is unique to the URL, not the
	URLRequest). Additionally, to refrain from duplicating data locally, if data is
	stored in the `NetworkCache`, it is also removed from the default `URLCache` if it
	exists.
	*/
	public let cache = NetworkCache()

	/// A default instance of NetworkHandler provided for convenience. Use is optional.
	public static let `default` = NetworkHandler()

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init() {}

	// MARK: - Network Handling
	/**
	Preconfigured URLSession tasking to fetch, decode, and provide decodable json data.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- useCache: Bool toggle indicating whether to use cache or not.
		**Default**: `false`
		- session: URLSession instance. **Default**: `URLSession.shared`
		- completion: completion closure run when the data task is finished.
		Provides a `Result` type argument providing `Data?` when there was a
		successful transaction, but a `NetworkError` when failure ocurred.
	- Returns: The resulting, generated `URLSessionDataTask`. In the event that
	you're either mocking or have `usingCache` flagged `true` and there is cached
	data, returns nil.
	*/
	@discardableResult public func transferMahCodableDatas<DecodableType: Decodable>(with request: NetworkRequest, usingCache useCache: Bool = false, session: NetworkLoader = URLSession.shared, completion: @escaping (Result<DecodableType, NetworkError>) -> Void) -> URLSessionDataTask? {

		let task = transferMahDatas(with: request, usingCache: useCache, session: session) { [weak self] result in
			guard let self = self else { return }
			let decoder = request.decoder

			var data = Data()
			do {
				data = try result.get()
			} catch {
				completion(.failure(error as? NetworkError ?? NetworkError.otherError(error: error)))
				return
			}

			do {
				let newType = try decoder.decode(DecodableType.self, from: data)
				completion(.success(newType))
			} catch {
				let nullData = "null".data(using: .utf8)!
				if data == nullData {
					completion(.failure(.dataWasNull))
					return
				}
				self.printToConsole("Error decoding data in \(#file) line: \(#line): \(error)")
				completion(.failure(.dataCodingError(specifically: error, sourceData: data)))
			}
		}
		return task
	}

	/**
	Preconfigured URLSession tasking to fetch and provide data.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- useCache: Bool toggle indicating whether to use cache or not.
		**Default**: `false`
		- session: URLSession instance. **Default**: `URLSession.shared`
		- completion: completion closure run when the data task is finished.
		Provides a `Result` type argument providing `Data?` when there was a
		successful transaction, but a `NetworkError` when failure ocurred.
	- Returns: The resulting, generated `URLSessionDataTask`. In the event that
	you're either mocking or have `usingCache` flagged `true` and there is cached
	data, returns nil.
	*/
	@discardableResult public func transferMahDatas(with request: NetworkRequest, usingCache useCache: Bool = false, session: NetworkLoader = URLSession.shared, completion: @escaping (Result<Data, NetworkError>) -> Void) -> URLSessionDataTask? {
		let task = transferMahOptionalDatas(with: request, usingCache: useCache, session: session) { (result: Result<Data?, NetworkError>) in
			do {
				let optData = try result.get()
				guard let data = optData else {
					self.printToConsole("\(String(describing: NetworkError.badData))")
					completion(.failure(.badData(sourceData: optData)))
					return
				}
				completion(.success(data))
			} catch {
				completion(.failure(error as? NetworkError ?? NetworkError.otherError(error: error)))
			}
		}
		return task
	}


	/**
	Preconfigured URLSession tasking to fetch and provide optional data,
	primarily for when you don't actually care about the response.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- useCache: Bool toggle indicating whether to use cache or not.
		**Default**: `false`
		- session: URLSession instance. **Default**: `URLSession.shared`
		- completion: completion closure run when the data task is finished.
		Provides a `Result` type argument providing `Data?` when there was a
		successful transaction, but a `NetworkError` when failure ocurred.
	 - Returns: The resulting, generated `URLSessionDataTask`. In the event that
		you're either mocking or have `usingCache` flagged `true` and there is cached
		data, returns nil.
	*/
	@discardableResult public func transferMahOptionalDatas(with request: NetworkRequest, usingCache useCache: Bool = false, session: NetworkLoader = URLSession.shared, completion: @escaping (Result<Data?, NetworkError>) -> Void) -> URLSessionDataTask? {
		if useCache {
			if let url = request.url, let data = cache[url] {
				completion(.success(data))
				return nil
			}
		}

		let task = session.loadData(with: request.urlRequest) { [weak self] data, response, error in
			guard let self = self else { return }
			if let response = response as? HTTPURLResponse {
				if !request.expectedResponseCodes.contains(response.statusCode) {
					self.printToConsole("Received an unexpected http response: \(response.statusCode) in \(#file) line: \(#line)")
					completion(.failure(.httpNon200StatusCode(code: response.statusCode, data: data)))
					return
				}
			} else {
				self.printToConsole("Did not receive a proper response code in \(#file) line: \(#line)")
				completion(.failure(.noStatusCodeResponse))
				return
			}

			if self.graphQLErrorSupport,
				let data = data,
				let errorContainer = try? JSONDecoder().decode(GQLErrorContainer.self, from: data),
				let error = errorContainer.errors.first {
				completion(.failure(.graphQLError(error: error)))
				return
			}

			if let error = error {
				self.printToConsole("An error was encountered: \(error) in \(#file) line: \(#line)")
				completion(.failure(error as? NetworkError ?? .otherError(error: error)))
				return
			}

			completion(.success(data))
			if useCache, let url = request.url, let data = data {
				// save into cache
				self.cache[url] = data
				// don't duplicate cached data
				URLCache.shared.removeCachedResponse(for: request.urlRequest)
			}
		}
		task?.resume()
		return task
	}

	private func printToConsole(_ string: String) {
		if printErrorsToConsole {
			print(string)
		}
	}
}
