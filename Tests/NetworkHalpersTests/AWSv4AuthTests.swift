import XCTest
@testable import NetworkHalpers
import TestSupport
import Crypto

class AWSv4AuthTests: XCTestCase {

	func testAWSSigning() {
		let url = URL(string: "https://s3.us-west-1.wasabisys.com/demoproject/?list-type=2&prefix=demo-subfolder%2FA%20Folder")!

		let formatter = ISO8601DateFormatter()
		let date = formatter.date(from: "2022-07-15T06:43:24Z")!

		let info = AWSV4Signature(
			requestMethod: .get,
			url: url,
			date: date,
			awsKey: "ASZUJQ6PHU62NDOW8Y2L",
			awsSecret: "t2wWpJDvLmeDTwnzCdzyeAHNeCG0LbE80FR50XbV",
			awsRegion: .usWest1,
			awsService: .s3,
			hexContentHash: SHA256.hash(data: Data("".utf8)).hex(),
			additionalSignedHeaders: [:])

		print(info)
	}
}
