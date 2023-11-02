import Foundation

extension NetworkHandler {
	/// (previousRequest, failedAttempts, mostRecentError)
	/// Return whatever option you wish to proceed with.
	public typealias RetryOptionBlock = (NetworkRequest, Int, NetworkError) -> RetryOption

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

	public struct DefaultReturnValueConfiguration {
		public var data: Data
		public var response: ResponseOption

		public enum ResponseOption {
			case full(HTTPURLResponse)
			case code(Int)
		}
	}

	public enum RetryOption {
		public static let retry = RetryOption.retryWithConfiguration(config: .simple)
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
}
