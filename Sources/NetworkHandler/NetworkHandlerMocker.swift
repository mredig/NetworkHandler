import Foundation
import NetworkHalpers

public class NetworkHandlerMocker: URLProtocol {
	@MainActor
	static private var acceptedIntercepts: [Key: (data: Data, statusCode: Int)] = [:]
	private struct Key: Hashable {
		let url: URL
		let method: HTTPMethod
	}

	public override class func canInit(with request: URLRequest) -> Bool { true }

	public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	@MainActor
	public static func addMock(for url: URL, method: HTTPMethod, data: Data, code: Int) async {
		acceptedIntercepts[Key(url: url, method: method)] = (data, code)
	}

	@MainActor
	public static func resetMocks() {
		acceptedIntercepts = [:]
	}

	public override func startLoading() {
		guard
			let url = request.url,
			let method = request.method
		else { fatalError() }

		Task {
			let data: Data
			let code: Int

			guard
				let result = await Self.acceptedIntercepts[Key(url: url, method: method)]
			else {
				client?.urlProtocol(self, didFailWithError: MockerError(message: "URL/Method combo not mocked"))
				return
			}
			data = result.data
			code = result.statusCode

			let response = HTTPURLResponse(
				url: url,
				statusCode: code,
				httpVersion: nil,
				headerFields: [
					"Content-Length": "\(data.count)",
				])!

			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

			let chunkSize = 256
			stride(from: 0, to: data.count, by: chunkSize)
				.forEach {
					let chunk = data[$0..<min($0 + chunkSize, data.count)]
					client?.urlProtocol(self, didLoad: chunk)
				}
			client?.urlProtocolDidFinishLoading(self)
		}
	}

	public override func stopLoading() {
		client?.urlProtocol(self, didFailWithError: MockerError(message: "Apparently Cancelled"))
	}

	struct MockerError: Error {
		let message: String
	}
}
