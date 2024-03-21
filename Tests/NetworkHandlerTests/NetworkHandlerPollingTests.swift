import XCTest
import NetworkHandler
import Crypto
import TestSupport
import Swiftwood
import PizzaMacros

/// Obviously dependent on network conditions
class NetworkHandlerPollingTests: NetworkHandlerBaseTest {
	@available(iOS 16.0, tvOS 16.0, *)
	func testPolling() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let sampleURL = #URL("https://s3.wasabisys.com/network-handler-tests/randomData.bin")
			.appending(queryItems: [
				URLQueryItem(name: "iteration", value: "1")
			])
		let resultURL = #URL("https://s3.wasabisys.com/network-handler-tests/randomData.bin")
			.appending(queryItems: [
				URLQueryItem(name: "iteration", value: "5")
			])
		let resultData = (Data(repeating: UInt8.random(in: 0...255), count: 1024 * 1024), 200)
		await NetworkHandlerMocker.addMock(for: sampleURL, requireQueryMatch: false, method: .get, smartBlock: { _, _, _ in
			resultData
		})

		let request = sampleURL.request

		let finalResult: (Data, HTTPURLResponse) = try await networkHandler.poll(
			request: request,
			until: { previousRequest, previousResult in
				guard
					let prevUrl = previousRequest.url,
					var components = URLComponents(url: prevUrl, resolvingAgainstBaseURL: false),
					var item = components.queryItems?.first(where: { $0.name == "iteration" }),
					let itemValue = item.value.flatMap({ Int($0) })
				else { throw SimpleTestError(message: "No url for some reason") }

				item.value = "\(itemValue + 1)"
				components.queryItems = [
					item
				]

				if itemValue == 5 {
					print("finishing: \(Date())")
					return .finish(previousResult)
				} else {
					let newRequest = components.url!.request
					print("continuing: \(Date())")
					return .continue(newRequest, 0.25)
				}
			})

		XCTAssertEqual(resultData.0, finalResult.0)
		XCTAssertEqual(resultData.1, finalResult.1.statusCode)
		XCTAssertEqual(resultURL, finalResult.1.url)
	}
}
