import AsyncHTTPClient
import NIOCore

extension UploadEngineRequest {
	var httpClientRequest: HTTPClientRequest {
		var request = HTTPClientRequest(url: self.url.absoluteURL.absoluteString)
		request.method = .init(rawValue: self.method.rawValue)
		request.headers = .init(self.headers.map { ($0.key.rawValue, $0.value.rawValue) })

		return request
	}
}
