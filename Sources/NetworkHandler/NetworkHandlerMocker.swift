import Foundation
import NetworkHalpers

public class NetworkHandlerMocker: URLProtocol {
	public typealias SmartResponseMockBlock = (URL, HTTPMethod) -> (data: Data, response: HTTPURLResponse)
	public typealias SmartMockBlock = (URL, HTTPMethod) -> (data: Data, code: Int)
	@MainActor
	static private var acceptedIntercepts: [Key: SmartResponseMockBlock] = [:]
	private struct Key: Hashable {
		let url: URL
		let method: HTTPMethod
	}

	public override class func canInit(with request: URLRequest) -> Bool { true }

	public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	@MainActor
	public static func addMock(for url: URL, method: HTTPMethod, data: Data, code: Int) {
		addMock(for: url, method: method, smartBlock: { _, _ in (data, code) })
	}

	@MainActor
	public static func addMock(for url: URL, method: HTTPMethod, smartResponseBlock: @escaping SmartResponseMockBlock) {
		acceptedIntercepts[Key(url: url, method: method)] = smartResponseBlock
	}

	@MainActor
	public static func addMock(for url: URL, method: HTTPMethod, smartBlock: @escaping SmartMockBlock) {
		addMock(for: url, method: method, smartResponseBlock: { url, method in
			let (data, code) = smartBlock(url, method)
			let response = HTTPURLResponse(
				url: url,
				statusCode: code,
				httpVersion: nil,
				headerFields: [
					"Content-Length": "\(data.count)",
				])!
			return (data, response)
		})
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

			guard
				let block = await Self.acceptedIntercepts[Key(url: url, method: method)]
			else {
				client?.urlProtocol(self, didFailWithError: MockerError(message: "URL/Method combo not mocked"))
				return
			}
			let result = block(url, method)
			data = result.data

			let response = result.response

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
