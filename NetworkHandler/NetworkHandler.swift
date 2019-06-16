//
//  NetworkHandler.swift
//
//  Created by Michael Redig on 5/7/19.
//  Copyright © 2019 Michael Redig. All rights reserved.
//
//swiftlint:disable line_length cyclomatic_complexity

import Foundation

public enum HTTPMethods: String {
	case post = "POST"
	case put = "PUT"
	case delete = "DELETE"
	case get = "GET"
	case head = "HEAD"
	case patch = "PATCH"
	case options = "OPTIONS"
}

public enum HTTPHeaderKeys: String {
	case contentType = "Content-Type"
	case auth = "Authorization"

	enum ContentTypes: String {
		case json = "application/json"
	}
}

public enum NetworkError: Error {
	case otherError(error: Error)
	case badData
	case dataCodingError(specifically: Error)
	case imageDecodeError
	case urlInvalid(urlString: String?)
	case noStatusCodeResponse
	case httpNon200StatusCode(code: Int, data: Data?)
	/// generically labeled to account for other databases, like Realm
	case databaseFailure(specifically: Error)
}

public class NetworkHandler {

	// MARK: - Properties
	public var printErrorsToConsole = false
	/**
	When true, results are only considered successful when the response code is
	*exactly* 200. False allows values anywhere in the 200-299 range to be
	considered successful.
	*/
	public var strict200CodeResponse = true
	/**
	The decoder used to decode JSON Codable data. You may edit its settings, just
	be aware that its settings apply to all decoding, not just for a single use.
	*/
	public lazy var netDecoder = {
		return JSONDecoder()
	}()

	/** If cache is used and there is a value in the cache for the requested
	key, a dummy URLSessionDataTask will be returned */
	public let cache = NetworkCache()

	/// A default instance of NetworkHandler provided for convenience. Use is optional.
	public static let `default` = NetworkHandler()

	// MARK: - Mocking Helpers
	/**
	Toggles the handler instance into mock mode or not. This must be set before
	`transferMahDatas` or its variants are called. 	In mock mode, you can provide
	test data to test your app in different scenarios providing different data and
	errors. Currently, 	mock mode will complete with *either* an error or data, but
	not both (both is possible in the real world).

		To use, set mock mode to trun, provide it with data (`mockData`) or an error
	(`mockError`), set `mockDelay` to emulate whatever 	level of network latency you
	wish to test, and set `mockSuccess` to determine whether you want to test
	success or failure.
	*/
	public var mockMode = false
	/**
	Data to provide in the event you want your mock mode test to succeed
	*/
	public var mockData: Data?
	/**
	Error to provide in the event you want your mock mode test to fail
	*/
	public var mockError: NetworkError?
	/**
	Determines if your mock mode test is successful or not - if successful, will
	return data, if not, will return the error
	*/
	public var mockSuccess = true
	/**
	Amount of time the mock mode test will take before completing its closures
	*/
	public var mockDelay: TimeInterval = 0.5

	/// Preconfigured URLSession tasking to fetch, decode, and provide decodable json data.
	@discardableResult public func transferMahCodableDatas<T: Decodable>(with request: URLRequest, usingCache useCache: Bool = false, session: URLSession = URLSession.shared, completion: @escaping (Result<T, NetworkError>) -> Void) -> URLSessionDataTask? {

		let task = transferMahDatas(with: request, usingCache: useCache, session: session) { [weak self] (result) in
			guard let self = self else { return }
			let decoder = self.netDecoder

			var data = Data()
			do {
				data = try result.get()
			} catch {
				completion(.failure(error as? NetworkError ?? NetworkError.otherError(error: error)))
				return
			}

			do {
				let newType = try decoder.decode(T.self, from: data)
				completion(.success(newType))
			} catch {
				self.printToConsole("Error decoding data in \(#file) line: \(#line): \(error)")
				completion(.failure(.dataCodingError(specifically: error)))
			}
		}
		return task
	}

	/// Preconfigured URLSession tasking to fetch and provide data.
	@discardableResult public func transferMahDatas(with request: URLRequest, usingCache useCache: Bool = false, session: URLSession = URLSession.shared, completion: @escaping (Result<Data, NetworkError>) -> Void) -> URLSessionDataTask? {
		let task = transferMahOptionalDatas(with: request, usingCache: useCache, session: session) { (result: Result<Data?, NetworkError>) in
			do {
				let optData = try result.get()
				guard let data = optData else {
					self.printToConsole("\(NetworkError.badData)")
					completion(.failure(.badData))
					return
				}
				completion(.success(data))
			} catch {
				completion(.failure(error as? NetworkError ?? NetworkError.otherError(error: error)))
			}
		}
		return task
	}

	/** Preconfigured URLSession tasking to fetch and provide optional data,
	primarily for when you don't actually care about the response. */
	@discardableResult public func transferMahOptionalDatas(with request: URLRequest, usingCache useCache: Bool = false, session: URLSession = URLSession.shared, completion: @escaping (Result<Data?, NetworkError>) -> Void) -> URLSessionDataTask? {
		if mockMode {
			DispatchQueue.global().asyncAfter(deadline: .now() + mockDelay) { [weak self] in
				guard let self = self else { return }
				if self.mockSuccess {
					guard let mockData = self.mockData else { fatalError("When mocking, you need to provide mock data for success.") }
					completion(.success(mockData))
				} else {
					guard let mockError = self.mockError else { fatalError("When mocking, you need to provide a mock error for failure.") }
					completion(.failure(mockError))
				}
			}
			return nil
		} else {
			if useCache {
				if let url = request.url, let data = cache[url] {
					completion(.success(data))
					return nil
				}
			}

			let task = session.dataTask(with: request) { [weak self] (data, response, error) in
				guard let self = self else { return }
				if let response = response as? HTTPURLResponse {
					if self.strict200CodeResponse && response.statusCode != 200 {
						self.printToConsole("Received a non 200 http response: \(response.statusCode) in \(#file) line: \(#line)")
						completion(.failure(.httpNon200StatusCode(code: response.statusCode, data: data)))
						return
					} else if !self.strict200CodeResponse && !(200..<300).contains(response.statusCode) {
						self.printToConsole("Received a non 200 http response: \(response.statusCode) in \(#file) line: \(#line)")
						completion(.failure(.httpNon200StatusCode(code: response.statusCode, data: data)))
						return
					}
				} else {
					self.printToConsole("Did not receive a proper response code in \(#file) line: \(#line)")
					completion(.failure(.noStatusCodeResponse))
					return
				}

				if let error = error {
					self.printToConsole("An error was encountered: \(error) in \(#file) line: \(#line)")
					completion(.failure(.otherError(error: error)))
					return
				}

				completion(.success(data))
				if useCache, let url = request.url, let data = data {
					self.cache[url] = data
				}
			}
			task.resume()
			return task
		}
	}

	private func printToConsole(_ string: String) {
		if printErrorsToConsole {
			print(string)
		}
	}
}
