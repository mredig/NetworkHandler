import Foundation

extension URLSessionConfiguration {
	/// Disables caching on the URLSession level as it would conflict with the caching provided via `NetworkHandler`.
	public static let networkHandlerDefault: URLSessionConfiguration = {
		let config = URLSessionConfiguration.default
		config.requestCachePolicy = .reloadIgnoringLocalCacheData
		config.urlCache = nil
		return config
	}()
}
