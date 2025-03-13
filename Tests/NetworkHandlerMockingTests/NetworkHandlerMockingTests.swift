import Testing
import Foundation
import TestSupport
import NetworkHandler
import NetworkHandlerMockingEngine
import Logging
import SwiftPizzaSnips

//@Suite(.serialized)
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
			{"id":"59747267-D47D-47CD-9E54-F79FA3C1F99B","imageURL":"https://s3.wasabisys.com/network-handler-tests/images/lighthouse.jpg","subtitle":"BarSub","title":"FooTitle"}
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
				originalRequest: .general(demo404URL.downloadRequest),
				data: nil))
	}

	@Test func handle404OmittedFromMocks() async throws {
		let mockingEngine = generateEngine()

		let demo404URL = commonTests.demo404URL

		try await commonTests.handle404Error(
			engine: mockingEngine,
			expectedError: NetworkError.httpUnexpectedStatusCode(
				code: 404,
				originalRequest: .general(demo404URL.downloadRequest),
				data: MockingEngine.noMockCreated404ErrorText(for: .general(demo404URL.downloadRequest)).data(using: .utf8)))
	}

	@Test func expect200OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		let demoModelURL = commonTests.demoModelURL

		await mockingEngine.addMock(for: demoModelURL, method: .get, responseData: nil, responseCode: 200)

		try await commonTests.expect200OnlyGet200(engine: mockingEngine)
	}

	@Test func expect201OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		let demoModelURL = commonTests.demoModelURL

		await mockingEngine.addMock(for: demoModelURL, method: .put, responseData: nil, responseCode: 200)

		try await commonTests.expect201OnlyGet200(engine: mockingEngine)
	}

	@Test func uploadData() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.randomDataURL
		await mockingEngine.addMock(for: url, method: .put) { server, request, _, requestBody in
			try await s3MockPutSimlulator(server: server, request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		}

		await mockingEngine.addMock(for: url, method: .get) { server, request, _, requestBody in
			try await s3MockGetSimulator(server: server, request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadData(engine: mockingEngine)
	}

	@Test func uploadFileURL() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, smartBlock: { server, request, _, requestBody in
			try await s3MockPutSimlulator(server: server, request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		})

		await mockingEngine.addMock(for: url, method: .get) { server, request, _, _ in
			try await s3MockGetSimulator(server: server, request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadFileURL(engine: mockingEngine)
	}

	@Test func uploadMultipartFile() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, smartBlock: { server, request, _, requestBody in
			try await s3MockPutSimlulator(server: server, request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		})

		await mockingEngine.addMock(for: url, method: .get) { server, request, _, _ in
			try await s3MockGetSimulator(server: server, request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadMultipartFile(engine: mockingEngine)
	}

	@Test func uploadMultipartStream() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, smartBlock: { server, request, _, requestBody in
			try await s3MockPutSimlulator(server: server, request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		})

		await mockingEngine.addMock(for: url, method: .get) { server, request, _, _ in
			try await s3MockGetSimulator(server: server, request: request, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadMultipartStream(engine: mockingEngine)
	}

	@Test func badCodingData() async throws {
		let mockingEngine = generateEngine()

		let modelStr = """
			{"id":"59747267-D47D-47CD-9E54-F79FA3C1F99B","imageURL":"https://s3.wasabisys.com/network-handler-tests/images/IMG_2932.jpg","subtitle":"BarSub",title":"FooTitle"}
			"""
		// missing a " before title
		let modelData = Data(modelStr.utf8)

		let url = commonTests.badDemoModelURL
		await mockingEngine.addMock(for: url, method: .get, responseData: modelData, responseCode: 200)

		try await commonTests.badCodableData(engine: mockingEngine)
	}

	@Test func cancellationViaToken() async throws {
		let mockingEngine = generateEngine()

		var rng: RandomNumberGenerator = SeedableRNG(seed: 394687)
		let modelData = Data.random(count: 1024 * 1024 * 10, using: &rng)

		let url = commonTests.randomDataURL
		await mockingEngine.addMock(for: url, method: .get, responseData: modelData, responseCode: 200)

		try await commonTests.cancellationViaToken(engine: mockingEngine)
	}

	@Test func cancellationViaStream() async throws {
		let mockingEngine = generateEngine()

		var rng: RandomNumberGenerator = SeedableRNG(seed: 394687)
		let modelData = Data.random(count: 1024 * 1024 * 10, using: &rng)

		let url = commonTests.randomDataURL
		await mockingEngine.addMock(for: url, method: .get, responseData: modelData, responseCode: 200)

		try await commonTests.cancellationViaStream(engine: mockingEngine)
	}

	@Test func uploadCancellationViaToken() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.uploadURL
		await mockingEngine.addMock(for: url, method: .put, responseData: nil, responseCode: 201)

		try await commonTests.uploadCancellationViaToken(engine: mockingEngine)
	}

	@Test func timeoutTriggersRetry() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.randomDataURL
		await mockingEngine.addMock(for: url, method: .put) { _, request, _, requestBody in
			try await Task.sleep(for: .seconds(5))
			return (nil, EngineResponseHeader(status: 201, url: request.url, headers: [:]))
		}

		try await commonTests.timeoutTriggersRetry(engine: mockingEngine)
	}

	@Test func downloadProgressTracking() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.randomDataURL
		var seedableRNG: RandomNumberGenerator = SeedableRNG(seed: 23785)
		await mockingEngine.addMock(for: url, method: .get, responseData: Data.random(count: 1024 * 1024 * 5, using: &seedableRNG), responseCode: 200)

		try await commonTests.downloadProgressTracking(engine: mockingEngine)
	}

	@Test func uploadProgressTracking() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.randomDataURL
		await mockingEngine.addMock(for: url, method: .put) { server, request, _, requestBody in
			try await s3MockPutSimlulator(server: server, request: request, requestBody: requestBody, mockingEngine: mockingEngine)
		}

		try await commonTests.uploadProgressTracking(engine: mockingEngine)
	}

	@Test func polling() async throws {
		let mockingEngine = generateEngine()

		let encoder = JSONEncoder()
		let responseBlock: MockingEngine.SmartResponseMockBlock = { server, request, pathItems, requestBody in
			let echo = NetworkHandlerCommonTests<MockingEngine>.BeeEchoModel(path: request.url.path(percentEncoded: false))
			let echoData = try encoder.encode(echo)
			return (echoData, EngineResponseHeader(status: 200, url: request.url, headers: [.contentLength: "\(echoData.count)"]))
		}

		let url = commonTests.echoURL
		let iterationURL = url.appending(component: ":iteration")
		await mockingEngine.addMock(for: url, method: .get, smartBlock: responseBlock)
		await mockingEngine.addMock(for: iterationURL, method: .get, smartBlock: responseBlock)

		try await commonTests.polling(engine: mockingEngine)
	}

	@Test func downloadFile() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.chonkURL

		let sizeOfUploadMB: UInt8 = 5
		let fileSize = Int(sizeOfUploadMB) * 1024 * 1024

		var rng: any RandomNumberGenerator = SeedableRNG(seed: 349687)
		let randomData = Data.random(count: fileSize, using: &rng)

		await mockingEngine.addMock(for: url, method: .get, responseData: randomData, responseCode: 200)

		try await commonTests.downloadFile(engine: mockingEngine)
	}

	/// This test (and the mocking engine block) has highly irregular behavior that probably has no real world
	/// application. However, it's not intended to replicate real world as much as test the varied scenarios for
	/// `NetworkHandler.RetryOption`. Because of these irregularities, it probably isn't worth replicating it to other
	/// engine tests (especially as `RetryOption` behavior happens outside the engine)
	@Test func retryOptions() async throws {
		let mockingEngine = generateEngine()

		let url = commonTests.randomDataURL
		await mockingEngine.addMock(for: url, method: .put) { server, request, pathItems, requestBody in
			if let previouslyUploaded = server.mockStorage[request.url.path(percentEncoded: false)], previouslyUploaded == requestBody {
				return (nil, EngineResponseHeader(status: 200, url: request.url, headers: [:]))
			} else {
				guard let uploadData = requestBody else {
					return (nil, EngineResponseHeader(status: 404, url: request.url, headers: [:]))
				}
				server.addStorage(uploadData, forKey: request.url.path(percentEncoded: false))
				return (nil, EngineResponseHeader(status: 201, url: request.url, headers: [:]))
			}
		}

		let expectedHeader = EngineResponseHeader(status: 200, url: url, headers: [:])

		try await commonTests.retryOptions(
			engine: mockingEngine,
			retryOption: .defaultReturnValue(data: "foo".data(using: .utf8)!, statusCode: 200),
			anticipatedOutput: .success((expectedHeader, "foo".data(using: .utf8)!)),
			expectedAttemptCount: 1)

		try await commonTests.retryOptions(
			engine: mockingEngine,
			retryOption: .defaultReturnValue(data: "foo".data(using: .utf8)!, urlResponse: EngineResponseHeader(status: 200, url: url, headers: [:])),
			anticipatedOutput: .success((expectedHeader, "foo".data(using: .utf8)!)),
			expectedAttemptCount: 1)

		let retryRequest = NetworkRequest.general(commonTests.demoModelURL.downloadRequest)
		try await commonTests.retryOptions(
			engine: mockingEngine,
			retryOption: .retry(withDelay: 0.5, updatedRequest: retryRequest),
			anticipatedOutput: .failure(.httpUnexpectedStatusCode(code: 404, originalRequest: retryRequest, data: nil)),
			expectedAttemptCount: 2)
	}

	private func generateEngine() -> MockingEngine {
		MockingEngine()
	}
}

extension NetworkHandlerMockingTests {
	private func s3MockPutSimlulator(server: MockingEngine.MockingServer, request: NetworkRequest, requestBody: Data?, mockingEngine: MockingEngine) async throws -> (data: Data?, response: EngineResponseHeader) {
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

		await server.addStorage(requestBody, forKey: request.url.path(percentEncoded: false))

		return (nil, EngineResponseHeader(status: 200, url: request.url, headers: [:]))
	}

	private func s3MockGetSimulator(server: MockingEngine.MockingServer, request: NetworkRequest, mockingEngine: MockingEngine) async throws -> (data: Data?, response: EngineResponseHeader) {
		guard
			let blob = await server.mockStorage[request.url.path(percentEncoded: false)]
		else { throw NetworkError.httpUnexpectedStatusCode(code: 404, originalRequest: request, data: Data("Requested object not found".utf8)) }

		return (blob, EngineResponseHeader(status: 200, url: request.url, headers: [.contentLength: "\(blob.count)"]))
	}
}
