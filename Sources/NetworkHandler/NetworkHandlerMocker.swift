import Foundation
import NetworkHalpers

public class NetworkHandlerMocker: URLProtocol {
	public typealias SmartResponseMockBlock = (
		URL,
		URLRequest,
		HTTPMethod
	) async throws -> (data: Data, response: HTTPURLResponse)
	public typealias SmartMockBlock = (URL, URLRequest, HTTPMethod) async throws -> (data: Data, code: Int)
	@MainActor
	static private var acceptedIntercepts: [Key: SmartResponseMockBlock] = [:]
	private struct Key: Hashable {
		let url: URL
		let requireQueryMatch: Bool
		let method: HTTPMethod

		init(url: URL, requireQueryMatch: Bool, method: HTTPMethod) {
			self.requireQueryMatch = requireQueryMatch
			if requireQueryMatch {
				self.url = url
			} else {
				var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
				comp?.queryItems = []
				self.url = comp?.url ?? url
			}
			self.method = method
		}
	}

	public override class func canInit(with request: URLRequest) -> Bool { true }

	public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	@MainActor
	private var isCancelled = false

	@MainActor
	public static func addMock(for url: URL, requireQueryMatch: Bool = true, method: HTTPMethod, data: Data, code: Int) {
		addMock(for: url, requireQueryMatch: requireQueryMatch, method: method, smartBlock: { _, _, _ in (data, code) })
	}

	@MainActor
	public static func addMock(
		for url: URL,
		requireQueryMatch: Bool = true,
		method: HTTPMethod,
		smartBlock: @escaping SmartMockBlock
	) {
		addMock(for: url, requireQueryMatch: requireQueryMatch, method: method, smartResponseBlock: { url, request, method in
			let (data, code) = try await smartBlock(url, request, method)
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
	public static func addMock(
		for url: URL,
		requireQueryMatch: Bool = true,
		method: HTTPMethod,
		smartResponseBlock: @escaping SmartResponseMockBlock
	) {
		acceptedIntercepts[Key(url: url, requireQueryMatch: requireQueryMatch, method: method)] = smartResponseBlock
	}

	@MainActor
	public static func resetMocks() {
		acceptedIntercepts = [:]
	}

	public override func startLoading() {
		guard
			let url = request.url,
			let method = request.method
		else { fatalError("A request made without url or method: \(request)") }

		Task {
			let data: Data

			let noQueryKey = Key(url: url, requireQueryMatch: false, method: method)
			let queryMatchKey = Key(url: url, requireQueryMatch: true, method: method)

			async let noQueryBlock = Self.acceptedIntercepts[noQueryKey]
			async let queryMatchBlock = Self.acceptedIntercepts[queryMatchKey]

			guard
				let block = await [noQueryBlock, queryMatchBlock].compactMap({ $0 }).first
			else {
				client?.urlProtocol(self, didFailWithError: MockerError(message: "URL/Method combo not mocked"))
				return
			}
			let result: (data: Data, response: HTTPURLResponse)
			do {
				result = try await block(url, request, method)
			} catch {
				let response = HTTPURLResponse(
					url: url,
					statusCode: 500,
					httpVersion: nil,
					headerFields: nil)!
				result = (Data("Server side mock error: \(error)".utf8), response)
			}
			data = result.data

			let response = result.response

			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

			let chunkSize = 256
			for offset in stride(from: 0, to: data.count, by: chunkSize) {
				guard await isCancelled == false else { return }
				let chunk = data[offset..<min(offset + chunkSize, data.count)]
				client?.urlProtocol(self, didLoad: chunk)
			}

			client?.urlProtocolDidFinishLoading(self)
		}
	}

	public override func stopLoading() {
		Task {
			await cancelLoad()
		}
		client?.urlProtocol(self, didFailWithError: MockerError(message: "Apparently Cancelled"))
	}

	@MainActor
	private func cancelLoad() {
		isCancelled = true
	}

	struct MockerError: Error, LocalizedError {
		let message: String

		var errorDescription: String? { message }
		var failureReason: String? { message }
		var helpAnchor: String? { message }
		var recoverySuggestion: String? { message }
	}
}
