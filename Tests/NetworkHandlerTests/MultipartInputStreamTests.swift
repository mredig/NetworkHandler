import XCTest
import NetworkHandler

class MultipartInputStreamTests: NetworkHandlerBaseTest {

	func testStreamConcatenationLargeChunks() throws {
		let expectedFinal = "Hello World!<html><body>this is a body</body></html>"

		let part1 = InputStream(data: "Hello ".data(using: .utf8)!)
		let part2 = InputStream(data: "World!".data(using: .utf8)!)
		let part3 = InputStream(url: try createTestFile())!

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
		let part3 = InputStream(url: try createTestFile())!

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
		let part3 = InputStream(url: try createTestFile())!

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

	func testMultipartUpload() throws {
		let networkHandler = generateNetworkHandlerInstance()

		let boundary = "__X_PAW_BOUNDARY__"
		let multipart = MultipartInputStream(boundary: boundary)

		let arbitraryData = "Odd input stream".data(using: .utf8)!
		let arbitraryStream = InputStream(data: arbitraryData)

		multipart.addPart(named: "Text", string: "tested")
		multipart.addPart(named: "Text2", stream: arbitraryStream, streamFilename: "text.txt", streamLength: arbitraryData.count)
		multipart.addPart(named: "File", fileURL: try createTestFile(), contentType: "text/html")

//		let waitForDownload = expectation(description: "asdgljkha")
		let url = URL(string: "https://httpbin.org/post")!
//		var request = URLRequest(url: url)

//		request.httpMethod = "POST"
//		request.httpBodyStream = multipart
//		request.addValue("multipart/form-data; charset=utf-8; boundary=__X_PAW_BOUNDARY__", forHTTPHeaderField: "Content-Type")
////		request.httpBody = finalData
//
//		//let sem = DispatchSemaphore(value: 0)
//		URLSession.shared.dataTask(with: request) { (data, response, err) in
//			if let error = err {
//				print("Error: \(error)")
//				return
//			}
//
//			guard let data = data else { return }
//			print(String(data: data, encoding: .utf8)!)
//			waitForDownload.fulfill()
//		//	sem.signal()
//		}.resume()

		let waitForDownload = expectation(description: "Wait for download")
		var request = url.request
		request.httpMethod = .post
		request.setValue(multipart.multipartContentTypeHeaderValue, forHTTPHeaderField: .contentType)
		request.httpBodyStream = multipart
		let handle = networkHandler.transferMahDatas(with: request, completion: { result in
			do {
				XCTAssertNoThrow(try result.get())
				let uploadedData = try result.get()
				let dict = try? JSONSerialization.jsonObject(with: uploadedData, options: []) as? [String: Any]
				let	rubberBand = dict?["form"] as? String
				print(rubberBand)
				print(String(data: uploadedData, encoding: .utf8)!)
//				XCTAssertEqual(uploadedData.md5().toHexString(), dataHash.toHexString())
			} catch {
				print("Error confirming upload: \(error)")
			}
			waitForDownload.fulfill()
		})

		wait(for: [waitForDownload], timeout: 30)
		XCTAssertEqual(handle.status, .completed)
	}

	// MARK: - common utilities
	private func createTestFile() throws -> URL {
		let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let testFileContents = "<html><body>this is a body</body></html>".data(using: .utf8)!
		try testFileContents.write(to: testFileURL)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: testFileURL)
		}
		return testFileURL
	}
}
