import AsyncHTTPClient
import NIOCore

extension UploadEngineRequest {
	public var httpClientRequest: HTTPClientRequest {
		var request = HTTPClientRequest(url: self.url.absoluteURL.absoluteString)
		request.method = .init(rawValue: self.method.rawValue)
		request.headers = .init(self.headers.map { ($0.key.rawValue, $0.value.rawValue) })

		return request
	}

	var httpClientFutureRequest: HTTPClient.Request {
		get throws {
			try HTTPClient.Request(
				url: self.url,
				method: .init(rawValue: self.method.rawValue),
				headers: .init(self.headers.map { ($0.key.rawValue, $0.value.rawValue) }),
				body: nil)
		}
	}
}
