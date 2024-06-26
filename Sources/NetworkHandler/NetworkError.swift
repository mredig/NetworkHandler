import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
Errors specific to networking with NetworkHandler. These specific cases are all
accounted for when using the included `UIAlertController` extension to provide a
*/
public enum NetworkError: Error, Equatable {
	/**
	A generic wrapper for when an `Error` doesn't otherwise fall under one of the
	predetermined categories.
	*/
	case otherError(error: Error)
	/**
	Occurs when a request is expecting data back, but either doesn't get any, or
	gets noticably corrupted data. Wraps the source data for debugging.
	*/
	case badData(sourceData: Data?)
	/**
	Occurs when using a `Codable` data type that can't get decoded or encoded. Wraps
	the original error and source data for debugging.
	*/
	case dataCodingError(specifically: Error, sourceData: Data?)
	/**
	Not used within the NetworkHandler framework, but a preset error available for
	use when attempting to decode an image from a remote source and failing.
	Compatible with the UIAlertController extension included.
	*/
	case imageDecodeError
	/**
	Not used within the NetworkHandler framework, but a preset error available for
	use when a URL is invalid. Can wrap the offending `String`. Compatible with the
	UIAlertController extension included.
	*/
	case urlInvalid(urlString: String?)
	/// Thrown when a `URLResponse` doesn't include a valid response code.
	case noStatusCodeResponse
	/**
	Thrown when a `URLResponse` includes a response code other than 200, or a range
	of 200-299 (depending on whether `strict200CodeResponse` is on or off). Wraps
	the response code and included `Data?`, is there is any.
	*/
	case httpNon200StatusCode(code: Int, originalRequest: NetworkRequest, data: Data?)
	/**
	Not used within the NetworkHandler framework, but a preset error available for
	use when there's an error with whatever database you're using. Wraps the
	original `Error`. Generically labeled to account for other databases, like Realm
	or CoreData. Compatible with the UIAlertController extension included.
	*/
	case databaseFailure(specifically: Error)
	/**
	Some APIs (Firebase) will return a value of `null` when the request yields no
	results. Sometimes this is okay, so in those cases, you can check for if this is
	the case and proceed logically (for example, don't show the user an error and
	instead just show a lack of data shown in the event of an empty list)

	Note that the user presented alert associated with this error is NOT helpful,
	so if this can be reasonably expected at all, you want to try to handle it
	internally.

	```
	do {
		let result = try results.get()
	} catch NetworkError.dataWasNull {
		// oh okay, no results... just empty the model controller array
	} catch {
		// Another error occured, handle it!
	}
	```
	*/
	case noURLResponse
	case requestCancelled
	/**
	If you need to provide an error state but none of the other specified cases
	apply, use this. Optionally provide a reason. Useful for when guard statements fail.
	*/
	case unspecifiedError(reason: String?)

	// swiftlint:disable:next cyclomatic_complexity
	public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
		switch lhs {
		case .badData(let lhsSourceData):
			if case .badData(let rhsSourceData) = rhs, lhsSourceData == rhsSourceData { return true } else { return false }
		case .databaseFailure(specifically: let otherError):
			if
				case .databaseFailure(let rhsError) = rhs,
				otherError.localizedDescription == rhsError.localizedDescription {

				return true
			} else {
				return false
			}
		case .dataCodingError(specifically: let otherError, let lhsSourceData):
			if case .dataCodingError(let rhsError, let rhsSourceData) = rhs,
				otherError.localizedDescription == rhsError.localizedDescription,
			lhsSourceData == rhsSourceData { return true } else { return false }
		case .httpNon200StatusCode(code: let code, originalRequest: let request, data: let data):
			if
				case .httpNon200StatusCode(let rhsCode, let rhsRequest, let rhsData) = rhs,
				code == rhsCode,
				data == rhsData,
				request.urlRequest == rhsRequest.urlRequest {

				return true
			} else {
				return false
			}
		case .imageDecodeError:
			if case .imageDecodeError = rhs { return true } else { return false }
		case .noStatusCodeResponse:
			if case .noStatusCodeResponse = rhs { return true } else { return false }
		case .otherError(let otherError):
			if
				case .otherError(let rhsError) = rhs,
				otherError.localizedDescription == rhsError.localizedDescription {

				return true
			} else {
				return false
			}
		case .urlInvalid(let urlString):
			if case .urlInvalid(let rhsURLString) = rhs, urlString == rhsURLString { return true } else { return false }
		case .unspecifiedError(let lhsReason):
			if case .unspecifiedError(let rhsReason) = rhs, lhsReason == rhsReason { return true } else { return false }
		case .requestCancelled:
			if case .requestCancelled = rhs { return true } else { return false }
		case .noURLResponse:
			if case .noURLResponse = rhs { return true } else { return false }
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
		case .badData(sourceData: let sourceData):
			return "NetworkError: BadData (\(stringifyData(sourceData)))"
		case .databaseFailure(specifically: let error):
			return "NetworkError: Database Failure: (\(error))"
		case .dataCodingError(specifically: let error, sourceData: let sourceData):
			return "NetworkError: Data Coding Error\n Error: \(error)\nSourceData: \(stringifyData(sourceData))"
		case .httpNon200StatusCode(code: let code, originalRequest: let request, data: let data):
			let requestInfo = {
				let method = request.httpMethod?.rawValue ?? ("UNKNOWN_METHOD")
				let url = request.url?.absoluteString ?? "unknown url"

				var combined = "\(method)): \(url)"
				if let requestID = request.requestID {
					combined = "(\(requestID) \(combined)"
				} else {
					combined = "(\(combined)"
				}
				return combined
			}()
			return "NetworkError: Bad Response Code (\(code)) for request: \(requestInfo) with data: \(stringifyData(data))"
		case .imageDecodeError:
			return "NetworkError: Image Decode Error"
		case .noStatusCodeResponse:
			return "NetworkError: No Status Code in Response"
		case .unspecifiedError(reason: let reason):
			return "NetworkError: Unspecified Error: \(reason ?? "nil value")"
		case .urlInvalid(urlString: let urlString):
			return "NetworkError: Invalid URL: \(urlString ?? "nil value")"
		case .requestCancelled:
			return "NetworkError: Request was cancelled"
		case .noURLResponse:
			return "NetworkError: No URL Response"
		}
	}

	public var errorDescription: String? { debugDescription }

	public var failureReason: String? { debugDescription }

	public var helpAnchor: String? { debugDescription }

	public var recoverySuggestion: String? { debugDescription }
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
			return false
		}
	}

	/// Checks for cancellation errors (via `checkForCancellation()`) and, if it is cancellation, returns
	/// `NetworkError.requestCancelled`
	func convertToNetworkErrorIfCancellation() -> Error {
		if self is NetworkError {
			return self
		} else {
			guard isCancellation() else { return NetworkError.otherError(error: self) }
			return NetworkError.requestCancelled
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
