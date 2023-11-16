import XCTest
@testable import NetworkHandler
import Crypto
import TestSupport
import Swiftwood

/// Obviously dependent on network conditions
class NetworkHandlerRetryRawDataTests: NetworkHandlerBaseTest {
	func testRetry3XSuccess() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://foo.bar/")!
		let iterations = AtomicValue(value: 1)

		let successString = "Success!"
		await NetworkHandlerMocker
			.addMock(
				for: url,
				requireQueryMatch: false,
				method: .get,
				smartBlock: { [iterations] _, _, _ in
					defer { iterations.value += 1 }

					guard
						iterations.value == 3
					else { return (Data("Failed successfully.".utf8), 500) }
					return (Data(successString.utf8), 200)
				})

		let request = url.request
		let result = try await networkHandler.transferMahDatas(
			for: request,
			onError: { _, failedAttempts, error in
				guard
					failedAttempts < 3,
					case .httpNon200StatusCode(let code, _) = error,
					code == 500
				else { return .throw }
				return .retry
			})

		XCTAssertEqual(Data(successString.utf8), result.data)
		XCTAssertEqual(200, result.response.statusCode)
	}

	@available(iOS 16.0, tvOS 16.0, *)
	func testRetry3XSuccessModifiedRequest() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://foo.bar/")!

		let successString = "Success!"
		await NetworkHandlerMocker
			.addMock(
				for: url,
				requireQueryMatch: false,
				method: .get,
				smartBlock: { requestedURL, _, _ in

					guard
						let components = URLComponents(url: requestedURL, resolvingAgainstBaseURL: false),
						let queryItem = components.queryItems?.first,
						queryItem.name == "iteration",
						queryItem.value == "3"
					else { return (Data("Failed successfully.".utf8), 500) }
					return (Data(successString.utf8), 200)
				})

		let request = url
			.appending(queryItems: [
				URLQueryItem(name: "iteration", value: "1")
			])
			.request
		let failedAttemptCounter = AtomicValue(value: 0)
		let result = try await networkHandler.transferMahDatas(
			for: request,
			onError: { [failedAttemptCounter] previousRequest, failedAttempts, error in
				failedAttemptCounter.value += 1
				guard
					failedAttempts < 3,
					case .httpNon200StatusCode(let code, _) = error,
					code == 500,
					let previousURL = previousRequest.url,
					var components = URLComponents(url: previousURL, resolvingAgainstBaseURL: false),
					var queryItem = components.queryItems?.first,
					queryItem.name == "iteration",
					let iteration = queryItem.value.flatMap(Int.init)
				else { return .throw }

				queryItem.value = "\(iteration + 1)"

				components.queryItems = [queryItem]

				var newRequest = previousRequest
				newRequest.url = components.url

				return .retry(updatedRequest: newRequest)
			})

		XCTAssertEqual(Data(successString.utf8), result.data)
		XCTAssertEqual(200, result.response.statusCode)
		XCTAssertEqual(2, failedAttemptCounter.value)
	}

	func testRetry3XFail() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://foo.bar/")!

		await NetworkHandlerMocker
			.addMock(
				for: url,
				requireQueryMatch: false,
				method: .get,
				smartBlock: { _, _, _ in
					(Data("Failed successfully.".utf8), 500)
				})

		let failedAttemptCounter = AtomicValue(value: 0)

		let request = url.request
		let result = await Task {
			try await networkHandler.transferMahDatas(
				for: request,
				onError: { [failedAttemptCounter] _, failedAttempts, error in
					failedAttemptCounter.value += 1
					guard
						failedAttempts < 3,
						case .httpNon200StatusCode(let code, _) = error,
						code == 500
					else { return .throw }
					return .retry
				})
		}.result

		XCTAssertThrowsError(try result.get())
		XCTAssertEqual(3, failedAttemptCounter.value)
	}

	func testRetryCustomError() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://foo.bar/")!

		let iterations = AtomicValue(value: 0)
		let lastRequest = AtomicValue(value: Date.distantPast)
		await NetworkHandlerMocker
			.addMock(
				for: url,
				requireQueryMatch: false,
				method: .get,
				smartBlock: { [iterations, lastRequest] _, _, _ in
					iterations.value += 1
					defer { lastRequest.value = Date() }

					let timeSinceLastRequest = Date().timeIntervalSince(lastRequest.value)
					guard
						iterations.value > 1,
						timeSinceLastRequest > 1
					else {
						return (Data("Too many requests.".utf8), 429)
					}
					return (Data("Failed successfully.".utf8), 500)
				})

		let request = url.request
		let result = await Task {
			try await networkHandler.transferMahDatas(
				for: request,
				onError: { _, failedAttempts, error in
					guard failedAttempts < 3 else { return .throw }
					switch error {
					case .httpNon200StatusCode(code: let code, data: _):
						if code == 429 {
							return .retry(withDelay: 1.1)
						} else if code == 500 {
							return .throw(updatedError: NetworkError.unspecifiedError(reason: "Got it!"))
						} else {
							return .throw
						}
					default:
						return .throw
					}
				})
		}.result

		XCTAssertThrowsError(try result.get()) { error in
			guard
				let error = error as? NetworkError,
				case .unspecifiedError(reason: let reason) = error
			else {
				XCTFail("Incorrect Error")
				return
			}

			XCTAssertEqual("Got it!", reason)
		}
	}

	func testDefaultReturnValueFullResponse() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://foo.bar/")!
		let success = "Default Success"

		await NetworkHandlerMocker
			.addMock(
				for: url,
				requireQueryMatch: false,
				method: .get,
				smartBlock: { _, _, _ in
					(Data("Failed successfully.".utf8), 500)
				})

		let failedAttemptCounter = AtomicValue(value: 0)

		let request = url.request
		let result = try await networkHandler.transferMahDatas(
			for: request,
			onError: { [failedAttemptCounter] _, failedAttempts, error in
				failedAttemptCounter.value += 1
				guard
					failedAttempts == 3,
					case .httpNon200StatusCode(let code, _) = error,
					code == 500
				else { return .retry }
				let returnData = Data(success.utf8)
				return .defaultReturnValue(
					data: returnData,
					urlResponse: HTTPURLResponse(
						url: url,
						statusCode: 200,
						httpVersion: nil,
						headerFields: [
							"Content-Length": "\(returnData.count)",
						])!)
			})

		XCTAssertEqual(Data(success.utf8), result.data)
		XCTAssertEqual(3, failedAttemptCounter.value)
	}

	func testDefaultReturnValueStatusCode() async throws {
		let networkHandler = generateNetworkHandlerInstance()

		let url = URL(string: "https://foo.bar/")!
		let success = "Default Success"

		await NetworkHandlerMocker
			.addMock(
				for: url,
				requireQueryMatch: false,
				method: .get,
				smartBlock: { _, _, _ in
					(Data("Failed successfully.".utf8), 500)
				})

		let failedAttemptCounter = AtomicValue(value: 0)

		let request = url.request
		let result = try await networkHandler.transferMahDatas(
			for: request,
			onError: { [failedAttemptCounter] _, failedAttempts, error in
				failedAttemptCounter.value += 1
				guard
					failedAttempts == 3,
					case .httpNon200StatusCode(let code, _) = error,
					code == 500
				else { return .retry }
				let returnData = Data(success.utf8)
				return .defaultReturnValue(
					data: returnData,
					statusCode: 200)
			})

		XCTAssertEqual(Data(success.utf8), result.data)
		XCTAssertEqual(3, failedAttemptCounter.value)
	}
}
