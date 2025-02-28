import NetworkHalpers
import Foundation

extension EngineResponseHeader {
	public init(from response: HTTPURLResponse) {
		let headers = response.allHeaderFields.reduce(into: [HTTPHeaders.Header.Key: HTTPHeaders.Header.Value]()) {
			$0["\($1.key)"] = "\($1.value)"
		}
		self.init(status: response.statusCode, url: response.url, headers: HTTPHeaders(headers))
	}
}
