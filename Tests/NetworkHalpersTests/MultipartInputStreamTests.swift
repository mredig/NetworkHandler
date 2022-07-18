import XCTest
import NetworkHalpers
import TestSupport

class MultipartInputStreamTests: XCTestCase {

	func testStreamConcatenationLargeChunks() throws {
		let expectedFinal = "Hello World!<html><body>this is a body</body></html>"

		let part1 = InputStream(data: "Hello ".data(using: .utf8)!)
		let part2 = InputStream(data: "World!".data(using: .utf8)!)
		let part3 = InputStream(url: try createTestFile().0)!

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
		let part3 = InputStream(url: try createTestFile().0)!

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
		let part3 = InputStream(url: try createTestFile().0)!

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

	func testMultipartGeneration() throws {
		let boundary = "alskdglkasdjfglkajsdf"
		let multipart = MultipartFormInputStream(boundary: boundary)

		let arbText = "Odd input stream"
		let arbitraryData = arbText.data(using: .utf8)!

		let testedText = "tested"
		multipart.addPart(named: "Text", string: testedText)
		multipart.addPart(named: "File1", data: arbitraryData, filename: "text.txt")
		let (fileURL, _) = try createTestFile()
		try multipart.addPart(named: "File2", fileURL: fileURL, contentType: "text/html")

		let finalData = streamToData(multipart)

		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		let finalString = String(data: finalData, encoding: .utf8)
		XCTAssertEqual(expected, finalString)
	}

	func testMultipartFileCreation() async throws {
		let boundary = "alskdglkasdjfglkajsdf"
		let multipart = MultipartFormInputTempFile(boundary: boundary)

		let arbText = "Odd input stream"
		let arbitraryData = arbText.data(using: .utf8)!

		let testedText = "tested"
		multipart.addPart(named: "Text", string: testedText)
		multipart.addPart(named: "File1", data: arbitraryData, filename: "text.txt")
		let (fileURL, _) = try createTestFile()
		try multipart.addPart(named: "File2", fileURL: fileURL, contentType: "text/html")

		let renderedFile = try multipart.renderToFile()
		let finalData = try Data(contentsOf: renderedFile)

		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		let finalString = String(data: finalData, encoding: .utf8)
		XCTAssertEqual(expected, finalString)
	}

	/// Dependent on the service at `https://httpbin.org/`
//	func testMultipartUpload() throws {
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let boundary = "alskdglkasdjfglkajsdf"
//		let multipart = MultipartFormInputStream(boundary: boundary)
//
//		let arbText = "Odd input stream"
//		let arbitraryData = arbText.data(using: .utf8)!
//
//		let testedText = "tested"
//		multipart.addPart(named: "Text", string: testedText)
//		multipart.addPart(named: "File1", data: arbitraryData, filename: "text.txt")
//		let (fileURL, fileContents) = try createTestFile()
//		try multipart.addPart(named: "File2", fileURL: fileURL, contentType: "text/html")
//
//		let url = URL(string: "https://httpbin.org/post")!
//		let waitForDownload = expectation(description: "Wait for download")
//		var request = url.request
//		request.httpMethod = .post
//		request.setValue(multipart.multipartContentTypeHeaderValue, forHTTPHeaderField: .contentType)
//		request.httpBodyStream = multipart
//		let handle = networkHandler.transferMahDatas(with: request, completion: { result in
//			do {
//				XCTAssertNoThrow(try result.get())
//				let uploadedData = try result.get()
//				let dict = try? JSONSerialization.jsonObject(with: uploadedData, options: []) as? [String: Any]
//				let	form = dict?["form"] as? [String: String]
//				let files = dict?["files"] as? [String: String]
//
//				XCTAssertEqual(arbText, files?["File1"])
//				XCTAssertEqual(fileContents, files?["File2"]?.data(using: .utf8))
//				XCTAssertEqual(testedText, form?["Text"])
//			} catch {
//				print("Error confirming upload: \(error)")
//			}
//			waitForDownload.fulfill()
//		})
//
//		wait(for: [waitForDownload], timeout: 30)
//		XCTAssertEqual(handle.status, .completed)
//	}

	func testStreamCopy() throws {
		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		let boundary = "alskdglkasdjfglkajsdf"
		let multipart = MultipartFormInputStream(boundary: boundary)

		let arbText = "Odd input stream"
		let arbitraryData = arbText.data(using: .utf8)!

		let testedText = "tested"
		multipart.addPart(named: "Text", string: testedText)
		multipart.addPart(named: "File1", data: arbitraryData, filename: "text.txt")
		let (fileURL, _) = try createTestFile()
		try multipart.addPart(named: "File2", fileURL: fileURL, contentType: "text/html")

		let theCopyBefore = multipart.copy() as! MultipartFormInputStream
		let theCopyData = streamToData(theCopyBefore)
		let copyString = String(data: theCopyData, encoding: .utf8)
		XCTAssertEqual(expected, copyString)

		let originalMultipartData = streamToData(multipart)
		let multipartString = String(data: originalMultipartData, encoding: .utf8)
		XCTAssertEqual(expected, multipartString)

		let theCopyAfter = multipart.copy() as! MultipartFormInputStream
		let theCopyAfterData = streamToData(theCopyAfter)
		let copyAfterString = String(data: theCopyAfterData, encoding: .utf8)
		XCTAssertEqual(expected, copyAfterString)
	}

	private func streamToData(_ stream: InputStream) -> Data {
		if stream.streamStatus == .notOpen {
			stream.open()
		}

		var readCount = 0
		var finalData = Data()
		while stream.hasBytesAvailable {
			let bufferSize = 20
			let testPoint = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
			let buffer = UnsafeMutableBufferPointer<UInt8>(start: testPoint, count: bufferSize)
			buffer.initialize(repeating: 0)

			readCount += stream.read(testPoint, maxLength: bufferSize)

			let data = Data(buffer: buffer)

			finalData += data
		}
		stream.close()

		finalData = finalData[0..<readCount]

		return finalData
	}

	// MARK: - common utilities
	private func createTestFile() throws -> (URL, Data) {
		let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let testFileContents = "<html><body>this is a body</body></html>".data(using: .utf8)!
		try testFileContents.write(to: testFileURL)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: testFileURL)
		}
		return (testFileURL, testFileContents)
	}
}
