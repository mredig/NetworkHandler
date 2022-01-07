import Foundation

extension URLSessionConfiguration {
	public static let networkHandlerDefault: URLSessionConfiguration = {
		let c = URLSessionConfiguration.default
		c.requestCachePolicy = .reloadIgnoringLocalCacheData
		c.urlCache = nil
		return c
	}()
}
