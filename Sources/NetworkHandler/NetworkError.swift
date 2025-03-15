import Foundation
import SwiftPizzaSnips
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors specific to networking with NetworkHandler. These specific cases are all
/// accounted for when using the included `UIAlertController` extension to provide a
public enum NetworkError: Error, Equatable {
	/// A generic wrapper for when an `Error` doesn't otherwise fall under one of the
	/// predetermined categories.
	case otherError(error: Error)
	/// Occurs when using a `Codable` data type that can't get decoded or encoded. Wraps
	/// the original error and source data for debugging.
	case dataCodingError(specifically: Error, sourceData: Data?)
	/// Occurs when using a method that automatically decodes server returned data, but no data is provided.
	case noData
	/// Thrown when a `URLResponse` includes a response code other than 200, or a range
	/// of 200-299 (depending on whether `strict200CodeResponse` is on or off). Wraps
	/// the response code and included `Data?`, if there is any.
	case httpUnexpectedStatusCode(code: Int, originalRequest: NetworkRequest, data: Data?)
	case requestCancelled
	/// If you need to provide an error state but none of the other specified cases
	/// apply, use this. Optionally provide a reason. Useful for when guard statements fail.
	case unspecifiedError(reason: String?)
	/// When the timeout for a given request elapses prior to finishing the request
	case requestTimedOut

	// swiftlint:disable:next cyclomatic_complexity
	public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
		switch lhs {
		case .dataCodingError(specifically: let otherError, let lhsSourceData):
			if
				case .dataCodingError(let rhsError, let rhsSourceData) = rhs,
				otherError.localizedDescription == rhsError.localizedDescription,
				lhsSourceData == rhsSourceData { return true } else { return false }
		case .httpUnexpectedStatusCode(code: let code, originalRequest: let request, data: let data):
			if
				case .httpUnexpectedStatusCode(let rhsCode, let rhsRequest, let rhsData) = rhs,
				code == rhsCode,
				data == rhsData,
				request == rhsRequest {

				return true
			} else {
				return false
			}
		case .otherError(let otherError):
			if
				case .otherError(let rhsError) = rhs,
				otherError.localizedDescription == rhsError.localizedDescription {

				return true
			} else {
				return false
			}
		case .unspecifiedError(let lhsReason):
			if case .unspecifiedError(let rhsReason) = rhs, lhsReason == rhsReason { return true } else { return false }
		case .requestCancelled:
			if case .requestCancelled = rhs { return true } else { return false }
		case .requestTimedOut:
			if case .requestTimedOut = rhs { return true } else { return false }
		case .noData:
			if case .noData = rhs { return true } else { return false }
		}
	}

	nonisolated(unsafe)
	private static var registeredCancellationErrors: [String: (any Error) -> Bool] = [:]
	nonisolated(unsafe)
	private static var registeredTimeoutErrors: [String: (any Error) -> Bool] = [:]

	static fileprivate let registrationLock = MutexLock()
	static func registerCancellationErrorHandling(_ handler: @escaping (any Error) -> Bool, forEngine engine: String) {
		registrationLock.withLock {
			registeredCancellationErrors[engine] = handler
		}
	}

	static func registerTimeoutErrorHandling(_ handler: @escaping (any Error) -> Bool, forEngine engine: String) {
		registrationLock.withLock {
			registeredTimeoutErrors[engine] = handler
		}
	}

	static func isRegisteredCancellationError(_ error: any Error) -> Bool {
		registrationLock.withLock {
			registeredCancellationErrors.values.contains(where: { $0(error) })
		}
	}

	static func isRegisteredTimeoutError(_ error: any Error) -> Bool {
		registrationLock.withLock {
			registeredTimeoutErrors.values.contains(where: { $0(error) })
		}
	}
}

extension NetworkError: CustomDebugStringConvertible, LocalizedError {
	private func stringifyData(_ data: Data?) -> String {
		guard let data = data else { return "nil value" }
		return String(data: data, encoding: .utf8) ??
			String(data: data, encoding: .unicode) ??
			String(data: data, encoding: .utf16) ??
			"Non string data: \(data)"
	}

	public var debugDescription: String {
		switch self {
		case .otherError(error: let error):
			return "NetworkError: OtherError (\(error))"
		case .dataCodingError(specifically: let error, sourceData: let sourceData):
			return "NetworkError: Data Coding Error\n Error: \(error)\nSourceData: \(stringifyData(sourceData))"
		case .httpUnexpectedStatusCode(code: let code, originalRequest: let request, data: let data):
			let requestInfo = {
				let method = request.method.rawValue
				let url = request.url.absoluteString

				var combined = "\(method)): \(url)"
				if let requestID = request.requestID {
					combined = "(\(requestID) \(combined)"
				} else {
					combined = "(\(combined)"
				}
				return combined
			}()
			return "NetworkError: Bad Response Code (\(code)) for request: \(requestInfo) with data: \(stringifyData(data))"
		case .unspecifiedError(reason: let reason):
			return "NetworkError: Unspecified Error: \(reason ?? "nil value")"
		case .requestCancelled:
			return "NetworkError: Request was cancelled"
		case .requestTimedOut:
			return "NetworkError: Request timed out"
		case .noData:
			return "NetworkError: No data from server"
		}
	}

	public var errorDescription: String? { debugDescription }

	public var failureReason: String? { debugDescription }

	public var helpAnchor: String? { debugDescription }

	public var recoverySuggestion: String? { debugDescription }

	public static func convert<E: Error>(_ error: E) -> NetworkError {
		guard (error is NetworkError) == false else {
			return error as! NetworkError
		}
		guard error.isCancellation() == false else {
			return .requestCancelled
		}
		guard error.isTimeout() == false else {
			return .requestTimedOut
		}
		return .otherError(error: error)
	}

	/// Since networking is fraught with potential errors, `NetworkHandler` tries to normalize them into
	/// `NetworkError` using `NetworkError.captureAndConvert()`. It is also expected to use
	/// this method to wrap errors encountered when writing the implementation of a `NetworkEngine`.
	/// - Parameter block: The code which can throw
	public static func captureAndConvert<T, E>(_ block: () throws(E) -> T) throws(NetworkError) -> T {
		do {
			return try block()
		} catch {
			throw convert(error)
		}
	}

	/// Since networking is fraught with potential errors, `NetworkHandler` tries to normalize them into
	/// `NetworkError` using `NetworkError.captureAndConvert()`. It is also expected to use
	/// this method to wrap errors encountered when writing the implementation of a `NetworkEngine`.
	/// - Parameter block: The code which can throw
	public static func captureAndConvert<T: Sendable, E>(
		_ block: sending @isolated(any) () async throws(E) -> T
	) async throws(NetworkError) -> T {
		do {
			return try await block()
		} catch {
			throw convert(error)
		}
	}
}

public extension Error {
	/// Checks for cancellation errors related to networking or `CancellationError` and returns true if for cancellation.
	func isCancellation() -> Bool {
		if
			case let error = self as NSError,
			error.domain == NSURLErrorDomain,
			error.code == NSURLErrorCancelled {
			
			return true
		} else if self is CancellationError {
			return true
		} else if let error = self as? NetworkError, error == .requestCancelled {
			return true
		} else {
			return NetworkError.isRegisteredCancellationError(self)
		}
	}

	func isTimeout() -> Bool {
		if
			case let error = self as NSError,
			error.domain == NSURLErrorDomain,
			error.code == NSURLErrorTimedOut {

			return true
		} else if let error = self as? NetworkError, error == .requestTimedOut {
			return true
		} else {
			return NetworkError.isRegisteredTimeoutError(self)
		}
	}
}

public extension Task {
	static func checkCancellationForNetworkRequest() throws where Success == Never, Failure == Never {
		guard
			Task.isCancelled == false
		else { throw NetworkError.requestCancelled }
		return
	}
}
