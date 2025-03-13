import AsyncHTTPClient
import NIOCore
import NetworkHandler

extension GeneralEngineRequest {
	var httpClientRequest: HTTPClientRequest {
		var request = HTTPClientRequest(url: self.url.absoluteURL.absoluteString)
		request.method = .init(rawValue: self.method.rawValue)
		request.headers = .init(self.headers.map { ($0.key.rawValue, $0.value.rawValue) })

		if let payload {
			request.body = .bytes(ByteBuffer(bytes: payload))
		}

		return request
	}
}
