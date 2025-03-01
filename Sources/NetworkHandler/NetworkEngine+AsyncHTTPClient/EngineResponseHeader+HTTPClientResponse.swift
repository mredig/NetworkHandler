import NetworkHalpers
import AsyncHTTPClient
import Foundation

extension EngineResponseHeader {
	public init(from response: HTTPClientResponse, with url: URL) {
		let statusCode = Int(response.status.code)
		let headerList = response.headers.map { HTTPHeaders.Header(key: "\($0.name)", value: "\($0.value)") }
		let headers = NetworkHalpers.HTTPHeaders(headerList)

		self.init(status: statusCode, url: url, headers: headers)
	}
}
