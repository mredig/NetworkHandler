import Foundation

extension NetworkHandler {
	/// (previousRequest, failedAttempts, mostRecentError)
	/// Return whatever option you wish to proceed with.
	public typealias RetryOptionBlock<T: Decodable> = (NetworkRequest, Int, NetworkError) -> RetryOption<T>

	public struct RetryConfiguration {
		public static let simple = RetryConfiguration(delay: 0)

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

	public struct DefaultReturnValueConfiguration<T: Decodable> {
		public var data: T
		public var response: ResponseOption

		public enum ResponseOption {
			case full(HTTPURLResponse)
			case code(Int)
		}
	}

	public enum RetryOption<T: Decodable> {
		public static var retry: RetryOption { .retryWithConfiguration(config: .simple) }
		case retryWithConfiguration(config: RetryConfiguration)
		public static func retry(
			withDelay delay: TimeInterval = 0,
			updatedRequest: NetworkRequest? = nil
		) -> RetryOption {
			let config = RetryConfiguration(delay: delay, updatedRequest: updatedRequest)
			return .retryWithConfiguration(config: config)
		}

		case `throw`(updatedError: Error?)
		public static var `throw`: RetryOption { .throw(updatedError: nil) }
		case defaultReturnValue(config: DefaultReturnValueConfiguration<T>)

		public static func defaultReturnValue(data: T, statusCode: Int) -> RetryOption {
			let config = DefaultReturnValueConfiguration(data: data, response: .code(statusCode))
			return .defaultReturnValue(config: config)
		}

		public static func defaultReturnValue(data: T, urlResponse: HTTPURLResponse) -> RetryOption {
			let config = DefaultReturnValueConfiguration(data: data, response: .full(urlResponse))
			return .defaultReturnValue(config: config)
		}
	}
}
