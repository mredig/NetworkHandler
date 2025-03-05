import Foundation
import SwiftPizzaSnips

extension NetworkHandler {
	/// (previousRequest, failedAttempts, mostRecentError)
	/// Return whatever option you wish to proceed with.
	public typealias RetryOptionBlock<T: Decodable> = @NHActor (NetworkRequest, Int, NetworkError) -> RetryOption<T>

	public struct RetryConfiguration: Hashable, Sendable, Withable {
		public static var simple: Self { RetryConfiguration(delay: 0) }

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

	public struct DefaultReturnValueConfiguration<T: Decodable>: Withable {
		public var data: T
		public var response: ResponseOption

		public enum ResponseOption: Hashable, Sendable, Withable {
			case full(EngineResponseHeader)
			case code(Int)
		}
	}

	public enum RetryOption<T: Decodable>: Withable {
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

		public static func defaultReturnValue(data: T, urlResponse: EngineResponseHeader) -> RetryOption {
			let config = DefaultReturnValueConfiguration(data: data, response: .full(urlResponse))
			return .defaultReturnValue(config: config)
		}
	}
}

extension NetworkHandler.DefaultReturnValueConfiguration: Equatable where T: Equatable {}
extension NetworkHandler.DefaultReturnValueConfiguration: Hashable where T: Hashable {}
