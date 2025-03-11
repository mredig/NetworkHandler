import AsyncHTTPClient
import NIOCore
import NetworkHandler

extension UploadEngineRequest {
	public var httpClientFutureRequest: HTTPClient.Request {
		get throws {
			try HTTPClient.Request(
				url: self.url,
				method: .init(rawValue: self.method.rawValue),
				headers: .init(self.headers.map { ($0.key.rawValue, $0.value.rawValue) }),
				body: nil)
		}
	}
}
