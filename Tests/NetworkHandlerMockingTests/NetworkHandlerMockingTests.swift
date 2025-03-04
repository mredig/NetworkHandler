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
			responseCode: 200)

		try await commonTests.downloadAndCacheImages(engine: mockingEngine)
	}

	private func generateEngine() -> MockingEngine {
		MockingEngine(passthroughEngine: nil)
	}
}
