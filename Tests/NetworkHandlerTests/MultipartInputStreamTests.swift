import XCTest
import NetworkHandler

class MultipartInputStreamTests: NetworkHandlerBaseTest {

	func testStreamConcatenationLargeChunks() throws {
		let expectedFinal = "Hello World!<html><body>this is a body</body></html>"

		let part1 = InputStream(data: "Hello ".data(using: .utf8)!)
		let part2 = InputStream(data: "World!".data(using: .utf8)!)

		let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let testFileContents = "<html><body>this is a body</body></html>".data(using: .utf8)!
		try testFileContents.write(to: testFileURL)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: testFileURL)
		}
		let part3 = InputStream(url: testFileURL)!

		let concat = try ConcatenatedInputStream(streams: [part1, part2, part3])

		let bufferSize = 100
		let testPoint = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
		let buffer = UnsafeMutableBufferPointer<UInt8>(start: testPoint, count: bufferSize)
		buffer.initialize(repeating: 0)

		let readCount = concat.read(testPoint, maxLength: bufferSize)

		var data = Data(buffer: buffer)
		data = data[0..<readCount]
		let finalString = String(data: data, encoding: .utf8)
		XCTAssertEqual(expectedFinal, finalString)
	}

	func testStreamConcatenationSmallChunks() throws {
		let expectedFinal = "Hello World!<html><body>this is a body</body></html>"

		let part1 = InputStream(data: "Hello ".data(using: .utf8)!)
		let part2 = InputStream(data: "World!".data(using: .utf8)!)

		let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let testFileContents = "<html><body>this is a body</body></html>".data(using: .utf8)!
		try testFileContents.write(to: testFileURL)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: testFileURL)
		}
		let part3 = InputStream(url: testFileURL)!

		let concat = try ConcatenatedInputStream(streams: [part1, part2, part3])

		var readCount = 0
		var finalData = Data()
		for _ in 0..<100 {
			let bufferSize = 1
			let testPoint = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
			let buffer = UnsafeMutableBufferPointer<UInt8>(start: testPoint, count: bufferSize)
			buffer.initialize(repeating: 0)

			readCount += concat.read(testPoint, maxLength: bufferSize)

			let data = Data(buffer: buffer)

			finalData += data
		}

		finalData = finalData[0..<readCount]
		let finalString = String(data: finalData, encoding: .utf8)
		XCTAssertEqual(expectedFinal, finalString)
	}

	func testStreamConcatenationMediumChunks() throws {
		let expectedFinal = "Hello World!<html><body>this is a body</body></html>"

		let part1 = InputStream(data: "Hello ".data(using: .utf8)!)
		let part2 = InputStream(data: "World!".data(using: .utf8)!)

		let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let testFileContents = "<html><body>this is a body</body></html>".data(using: .utf8)!
		try testFileContents.write(to: testFileURL)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: testFileURL)
		}
		let part3 = InputStream(url: testFileURL)!

		let concat = try ConcatenatedInputStream(streams: [part1, part2, part3])

		var readCount = 0
		var finalData = Data()
		for _ in 0..<100 {
			let bufferSize = 6
			let testPoint = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
			let buffer = UnsafeMutableBufferPointer<UInt8>(start: testPoint, count: bufferSize)
			buffer.initialize(repeating: 0)

			readCount += concat.read(testPoint, maxLength: bufferSize)

			let data = Data(buffer: buffer)

			finalData += data
		}

		finalData = finalData[0..<readCount]
		let finalString = String(data: finalData, encoding: .utf8)
		XCTAssertEqual(expectedFinal, finalString)

	}
}
