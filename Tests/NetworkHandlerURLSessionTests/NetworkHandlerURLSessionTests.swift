import Testing
import Foundation
import TestSupport
import NetworkHandler
import NetworkHandlerURLSessionEngine
import Logging
import SwiftPizzaSnips

@Suite(.serialized)
struct NetworkHandlerURLSessionTests: Sendable {
	let commonTests = NetworkHandlerCommonTests<URLSession>(logger: Logger(label: #fileID))

	@Test func downloadAndCacheImages() async throws {
		let mockingEngine = generateEngine()

		let lighthouseURL = Bundle.testBundle.url(forResource: "lighthouse", withExtension: "jpg", subdirectory: "Resources")!
		let lighthouseData = try Data(contentsOf: lighthouseURL)

		try await commonTests.downloadAndCacheImages(engine: mockingEngine, imageExpectationData: lighthouseData)
	}

	@Test func downloadAndDecodeData() async throws {
		let mockingEngine = generateEngine()

		let modelURL = commonTests.demoModelURL

		let testModel = DemoModel(
			id: UUID(uuidString: "59747267-D47D-47CD-9E54-F79FA3C1F99B")!,
			title: "FooTitle",
			subtitle: "BarSub",
			imageURL: commonTests.imageURL)

		try await commonTests.downloadAndDecodeData(engine: mockingEngine, modelURL: modelURL, expectedModel: testModel)
	}

	@Test func handle404() async throws {
		let mockingEngine = generateEngine()

		let demo404URL = commonTests.demo404URL

		try await commonTests.handle404Error(
			engine: mockingEngine,
			expectedError: NetworkError.httpUnexpectedStatusCode(
				code: 404,
				originalRequest: .download(demo404URL.downloadRequest),
				data: nil))
	}

	@Test func expect200OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.expect200OnlyGet200(engine: mockingEngine)
	}

	@Test func expect201OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.expect201OnlyGet200(engine: mockingEngine)
	}

	@Test func backgroundSessionUpload() async throws {
		let config = URLSessionConfiguration.background(withIdentifier: "backgroundID").with {
			$0.requestCachePolicy = .reloadIgnoringLocalCacheData
			$0.urlCache = nil
		}

		let engine = URLSession.asEngine(withConfiguration: config)

		try await commonTests.uploadFileURL(engine: engine)
	}

	@Test func uploadData() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.uploadData(engine: mockingEngine)
	}

	@Test func uploadFileURL() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadFileURL(engine: mockingEngine)
	}

	@Test func uploadMultipartFile() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadMultipartFile(engine: mockingEngine)
	}

	@Test func uploadMultipartStream() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.uploadMultipartStream(engine: mockingEngine)
	}

	@Test func badCodingData() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.badCodableData(engine: mockingEngine)
	}

	@Test func cancellationViaToken() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.cancellationViaToken(engine: mockingEngine)
	}

	@Test func cancellationViaStream() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.cancellationViaStream(engine: mockingEngine)
	}

	@Test func uploadCancellationViaToken() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.uploadCancellationViaToken(engine: mockingEngine)
	}

	@Test func timeoutTriggersRetry() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.timeoutTriggersRetry(engine: mockingEngine)
	}

	@Test func downloadProgressTracking() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.downloadProgressTracking(engine: mockingEngine)
	}

	@Test func uploadProgressTracking() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadProgressTracking(engine: mockingEngine)
	}

	@Test func polling() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.polling(engine: mockingEngine)
	}

	@Test func downloadFile() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.downloadFile(engine: mockingEngine)
	}

	private func generateEngine() -> URLSession {
		URLSession.asEngine(withConfiguration: .networkHandlerDefault)
	}
}
