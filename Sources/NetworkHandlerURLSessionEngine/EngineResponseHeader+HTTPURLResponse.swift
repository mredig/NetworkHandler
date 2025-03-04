import Foundation
import NetworkHandler

extension EngineResponseHeader {
	public init(from response: URLResponse) {
		let headers: HTTPHeaders
		let statusCode: Int
		if let httpResponse = response as? HTTPURLResponse {
			let headerList = httpResponse.allHeaderFields.map { HTTPHeaders.Header(key: "\($0.key)", value: "\($0.value)") }
			headers = HTTPHeaders(headerList)
			statusCode = httpResponse.statusCode
		} else {
			headers = HTTPHeaders(["ERROR": "Invalid response object - Not an HTTPURLResponse"])
			statusCode = -1
		}

		self.init(status: statusCode, url: response.url, headers: headers)
	}
}
