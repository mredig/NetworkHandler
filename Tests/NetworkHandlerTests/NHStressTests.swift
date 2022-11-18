import XCTest
//@testable import KnowMeEngine
//@testable import KnowMeMockResources
@testable import NetworkHandler
import Swizzles


@MainActor
final class NHStressTests: XCTestCase {
	func testStressingNetworkCallsAndDecodingManyTimes() async throws {
		for i in 1...99999 {
			let start = Date()
			print("starting iteration \(i)")
			_ = await Task {
				try await testStressingNetworkCallsAndDecoding()
			}.result

			let end = Date()
			print("stopping iteration \(i): took \(end.timeIntervalSince1970 - start.timeIntervalSince1970) seconds")
		}
	}

	func testStressingNetworkCallsAndDecoding() async throws {
		let networkHandler = NetworkHandler(name: "testing")

		let url = URL(string: "https://mredig-fileshare.s3.us-west-1.wasabisys.com/sample.json?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=T133H6EBRDX7CL0Z2P3M/20221012/us-east-1/s3/aws4_request&X-Amz-Date=20221012T230010Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=2efcddbeb13e92eb49afaf929ef2ee0ddb513c3a7772d6a62240c7be77c2bda4")!
		var request = url.request
		request.cachePolicy = .returnCacheDataDontLoad
		let delegate = OnTheDL()

		let (objects, _): ([Randos], URLResponse) = try await networkHandler.transferMahCodableDatas(for: url.request, delegate: delegate)

		print(objects.count)
	}

	func tetGenerateSomeJSON() throws {
		let objects = (0...50).map { _ in Randos() }

		let encoder = JSONEncoder()
		let data = try encoder.encode(objects)

		print(String(data: data, encoding: .utf8)!)
	}
	struct Randos: Codable {
		let someString: String
		let someInt: Int
		let abul: Bool
		let afloat: Double
		let aRay: [String]
		let dicktion: [Int: String]

		init() {
			let alpha = "abcdefghijklmnopqrstuvwxyz"
			let alphaNumsStr = alpha.uppercased() + alpha + " "
			let alphaNums = Set(alphaNumsStr)
			self.someString = (5...500).compactMap({ _ in String(alphaNums.randomElement()!) }).joined()
			self.someInt = Int.random(in: 5...5000000000)
			self.abul = Bool.random()
			self.afloat = Double.random(in: -50000000...(.greatestFiniteMagnitude))
			self.aRay = (1..<Int.random(in: 2...100)).map { _ in (16...64).compactMap({ _ in String(alphaNums.randomElement()!) }).joined() }
			self.dicktion = (1...Int.random(in: 1...100)).reduce(into: [:], {
				$0[$1] = (8...16).compactMap({ _ in String(alphaNums.randomElement()!) }).joined()
			})
		}
	}
}

class OnTheDL: NSObject, NetworkHandlerTransferDelegate, URLSessionTaskDelegate {
	var task: URLSessionTask?

	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State) {
		print("\(task.taskIdentifier) state changed to: \(state)")
	}

	func networkHandlerTaskDidStart(_ task: URLSessionTask) {
		print("Started")
	}

	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double) {
		print("Progress: \(progress)")
	}
}