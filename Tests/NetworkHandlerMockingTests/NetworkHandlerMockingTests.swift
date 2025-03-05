import Testing
import Foundation
import TestSupport
import NetworkHandler
import NetworkHandlerMockingEngine
import Logging

struct NetworkHandlerMockingTests {
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

	private func generateEngine() -> MockingEngine {
		MockingEngine(passthroughEngine: nil)
	}
}
