import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLSessionConfiguration {
	public static let networkHandlerDefault: URLSessionConfiguration = {
		let config = URLSessionConfiguration.default
		config.requestCachePolicy = .reloadIgnoringLocalCacheData
		config.urlCache = nil
		return config
	}()
}
