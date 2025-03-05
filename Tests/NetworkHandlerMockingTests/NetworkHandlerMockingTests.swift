import Testing
import Foundation
import TestSupport
import NetworkHandler
import NetworkHandlerMockingEngine
import Logging

struct NetworkHandlerMockingTests: Sendable {
	let commonTests = NetworkHandlerCommonTests<MockingEngine>(logger: Logger(label: #fileID))

	@Test func downloadAndCacheImages() async throws {
		let mockingEngine = generateEngine()

		let lighthouseURL = Bundle.testBundle.url(forResource: "lighthouse", withExtension: "jpg", subdirectory: "Resources")!
		let lighthouseData = try Data(contentsOf: lighthouseURL)

		await mockingEngine.addMock(
			for: commonTests.imageURL,
			method: .get,
			responseData: lighthouseData,
			responseCode: 200,
			delay: 0.5)

		try await commonTests.downloadAndCacheImages(engine: mockingEngine, imageExpectationData: lighthouseData)
	}

	@Test func downloadAndDecodeData() async throws {
		let mockingEngine = generateEngine()

		let modelURL = commonTests.demoModelURL
		let modelStr = """
			{"id":"59747267-D47D-47CD-9E54-F79FA3C1F99B","imageURL":"https://s3.wasabisys.com/network-handler-tests/images/IMG_2932.jpg","subtitle":"BarSub","title":"FooTitle"}
			"""
		let modelData = Data(modelStr.utf8)

		await mockingEngine.addMock(for: modelURL, method: .get, responseData: modelData, responseCode: 200)

		let testModel = DemoModel(
			id: UUID(uuidString: "59747267-D47D-47CD-9E54-F79FA3C1F99B")!,
			title: "FooTitle",
			subtitle: "BarSub",
			imageURL: commonTests.imageURL)

		try await commonTests.downloadAndDecodeData(engine: mockingEngine, modelURL: modelURL, expectedModel: testModel)
	}

	@Test func handle404DeliberatelySetInMocks() async throws {
		let mockingEngine = generateEngine()

		let demo404URL = commonTests.demo404URL
		await mockingEngine.addMock(for: demo404URL, method: .get, responseData: nil, responseCode: 404)

		try await commonTests.handle404Error(
			engine: mockingEngine,
			expectedError: NetworkError.httpUnexpectedStatusCode(
				code: 404,
				originalRequest: .download(demo404URL.downloadRequest),
				data: nil))
	}

	@Test func handle404OmittedFromMocks() async throws {
		let mockingEngine = generateEngine()

		let demo404URL = commonTests.demo404URL

		try await commonTests.handle404Error(
			engine: mockingEngine,
			expectedError: NetworkError.httpUnexpectedStatusCode(
				code: 404,
				originalRequest: .download(demo404URL.downloadRequest),
				data: MockingEngine.noMockCreated404ErrorText(for: .download(demo404URL.downloadRequest)).data(using: .utf8)))
	}

	@Test func expect200OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		let demoModelURL = commonTests.demoModelURL

		await mockingEngine.addMock(for: demoModelURL, method: .get, responseData: nil, responseCode: 200)

		try await commonTests.expect200OnlyGet200(engine: mockingEngine)
	}

	@Test func expect200OnlyGet201() async throws {
		let mockingEngine = generateEngine()

		let demoModelURL = commonTests.demoModelURL

		await mockingEngine.addMock(for: demoModelURL, method: .post, responseData: nil, responseCode: 201)

		try await commonTests.expect200OnlyGet201(engine: mockingEngine)
	}

	@Test func uploadFileURL() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, smartBlock: { request, requestBody in
			try await s3MockPutSimlulator(request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		})

		await mockingEngine.addMock(for: url, method: .get) { request, _ in
			try await s3MockGetSimulator(request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadFileURL(engine: mockingEngine)
	}

	@Test func uploadMultipartFile() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, smartBlock: { request, requestBody in
			try await s3MockPutSimlulator(request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		})

		await mockingEngine.addMock(for: url, method: .get) { request, _ in
			try await s3MockGetSimulator(request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadMultipartFile(engine: mockingEngine)
	}

	@Test func uploadMultipartStream() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, smartBlock: { request, requestBody in
			try await s3MockPutSimlulator(request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		})

		await mockingEngine.addMock(for: url, method: .get) { request, _ in
			try await s3MockGetSimulator(request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadMultipartStream(engine: mockingEngine)
	}


	private func generateEngine() -> MockingEngine {
		MockingEngine(passthroughEngine: nil)
	}
}

extension NetworkHandlerMockingTests {
	private func s3MockPutSimlulator(request: NetworkRequest, requestBody: Data?, mockingEngine: MockingEngine) async throws -> (data: Data?, response: EngineResponseHeader) {
		guard
			request.method == .put,
			request.headers["x-amz-content-sha256"] != nil,
			request.headers["x-amz-date"] != nil,
			request.headers[.authorization] != nil
		else {
			throw NetworkError.httpUnexpectedStatusCode(code: 400, originalRequest: request, data: Data("Missing amz headers".utf8))
		}

		guard let requestBody else {
			throw NetworkError.httpUnexpectedStatusCode(code: 400, originalRequest: request, data: Data("No data provided".utf8))
		}

		await mockingEngine.addStorage(requestBody, forKey: request.url.path(percentEncoded: false))

		return (nil, EngineResponseHeader(status: 201, url: request.url, headers: [:]))
	}

	private func s3MockGetSimulator(request: NetworkRequest, mockingEngine: MockingEngine) async throws -> (data: Data?, response: EngineResponseHeader) {
		guard
			let blob = await mockingEngine.mockStorage[request.url.path(percentEncoded: false)]
		else { throw NetworkError.httpUnexpectedStatusCode(code: 404, originalRequest: request, data: Data("Requested object not found".utf8)) }

		return (blob, EngineResponseHeader(status: 200, url: request.url, headers: [.contentLength: "\(blob.count)"]))
	}
}
