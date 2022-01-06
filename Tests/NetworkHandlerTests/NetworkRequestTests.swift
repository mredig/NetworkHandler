import XCTest
//// swiftlint:disable function_body_length
//
//import XCTest
//import NetworkHalpers
//import TestSupport
//
///// Obviously dependent on network conditions
//class NetworkRequestTests: NetworkHandlerBaseTest {
//
//	/// Tests encoding and decoding a request body
//	func testEncodingGeneric() throws {
//		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)
//
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		var request = dummyURL.request
//
//		request.encodeData(testDummy)
//
//		XCTAssertNotNil(request.httpBody)
//
//		let bodyData = try XCTUnwrap(request.httpBody)
//
//		XCTAssertNoThrow(try request.decoder.decode(DummyType.self, from: bodyData))
//		XCTAssertEqual(testDummy, try request.decoder.decode(DummyType.self, from: bodyData))
//	}
//
//	/// Tests adding, setting, and getting header values
//	func testRequestHeaders() {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		var request = dummyURL.request
//
//		request.addValue(.json, forHTTPHeaderField: .contentType)
//		XCTAssertEqual("application/json", request.value(forHTTPHeaderField: .contentType))
//		request.setValue(.xml, forHTTPHeaderField: .contentType)
//		XCTAssertEqual("application/xml", request.value(forHTTPHeaderField: .contentType))
//		request.setValue("Bearer: 12345", forHTTPHeaderField: .authorization)
//		XCTAssertEqual(["Content-Type": "application/xml", "Authorization": "Bearer: 12345"], request.allHeaderFields)
//
//		request.setValue(nil, forHTTPHeaderField: .authorization)
//		XCTAssertEqual(["Content-Type": "application/xml"], request.allHeaderFields)
//		XCTAssertNil(request.value(forHTTPHeaderField: .authorization))
//
//		request.setValue("Arbitrary Value", forHTTPHeaderField: "Arbitrary Key")
//		XCTAssertEqual(["Content-Type": "application/xml", "Arbitrary Key": "Arbitrary Value"], request.allHeaderFields)
//
//		let allFields = ["Content-Type": "application/xml", "Authorization": "Bearer: 12345", "Arbitrary Key": "Arbitrary Value"]
//		request.allHeaderFields = allFields
//		XCTAssertEqual(allFields, request.allHeaderFields)
//
//		var request2 = dummyURL.request
//		request2.setValue(.audioMp4, forHTTPHeaderField: .contentType)
//		XCTAssertEqual("audio/mp4", request2.value(forHTTPHeaderField: .contentType))
//
//		request2.setContentType(.bmp)
//		XCTAssertEqual("image/bmp", request2.value(forHTTPHeaderField: .contentType))
//
//		request2.setAuthorization("Bearer asdlkqf")
//		XCTAssertEqual("Bearer asdlkqf", request2.value(forHTTPHeaderField: .authorization))
//	}
//
//	func testHeaderEquals() {
//		let contentKey = HTTPHeaderKey.contentType
//
//		let nilString: String? = nil
//
//		XCTAssertTrue("Content-Type" == contentKey)
//		XCTAssertTrue(contentKey == "Content-Type")
//		XCTAssertTrue("Content-Typo" != contentKey)
//		XCTAssertTrue(contentKey != "Content-Typo")
//		XCTAssertFalse(contentKey == nilString)
//
//		let gif = HTTPHeaderValue.gif
//
//		XCTAssertTrue("image/gif" == gif)
//		XCTAssertTrue(gif == "image/gif")
//		XCTAssertTrue("image/jif" != gif)
//		XCTAssertTrue(gif != "image/jif")
//		XCTAssertFalse(gif == nilString)
//	}
//
//	func testURLRequestMirroredProperties() {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		var request = dummyURL.request
//
//		request.cachePolicy = .returnCacheDataDontLoad
//		XCTAssertEqual(.returnCacheDataDontLoad, request.cachePolicy)
//		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
//		XCTAssertEqual(.reloadIgnoringLocalAndRemoteCacheData, request.cachePolicy)
//
//		XCTAssertEqual(dummyURL, request.url)
//		let otherURL = URL(string: "https://redeggproductions.com/otherURL")
//		request.url = otherURL
//		XCTAssertEqual(otherURL, request.url)
//
//		let dummyStream = InputStream(data: Data([1, 2, 3, 4, 5]))
//
//		XCTAssertNil(request.httpBodyStream)
//		request.httpBodyStream = dummyStream
//		XCTAssertEqual(dummyStream, request.httpBodyStream)
//
//		XCTAssertNil(request.mainDocumentURL)
//		request.mainDocumentURL = dummyURL
//		XCTAssertEqual(dummyURL, request.mainDocumentURL)
//
//		XCTAssertEqual(60, request.timeoutInterval)
//		request.timeoutInterval = 120
//		XCTAssertEqual(120, request.timeoutInterval)
//
//		request.httpShouldHandleCookies = false
//		XCTAssertFalse(request.httpShouldHandleCookies)
//		request.httpShouldHandleCookies = true
//		XCTAssertTrue(request.httpShouldHandleCookies)
//
//		request.httpShouldUsePipelining = false
//		XCTAssertFalse(request.httpShouldUsePipelining)
//		request.httpShouldUsePipelining = true
//		XCTAssertTrue(request.httpShouldUsePipelining)
//
//		request.allowsCellularAccess = false
//		XCTAssertFalse(request.allowsCellularAccess)
//		request.allowsCellularAccess = true
//		XCTAssertTrue(request.allowsCellularAccess)
//
//		request.networkServiceType = .avStreaming
//		XCTAssertEqual(.avStreaming, request.networkServiceType)
//		request.networkServiceType = .responsiveData
//		XCTAssertEqual(.responsiveData, request.networkServiceType)
//
//		#if !os(Linux)
//		if #available(iOS 13.0, OSX 10.15, *) {
//			request.allowsExpensiveNetworkAccess = false
//			XCTAssertFalse(request.allowsExpensiveNetworkAccess)
//			request.allowsExpensiveNetworkAccess = true
//			XCTAssertTrue(request.allowsExpensiveNetworkAccess)
//
//			request.allowsConstrainedNetworkAccess = false
//			XCTAssertFalse(request.allowsConstrainedNetworkAccess)
//			request.allowsConstrainedNetworkAccess = true
//			XCTAssertTrue(request.allowsConstrainedNetworkAccess)
//		}
//		#endif
//	}
//
//	func testPriority() {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		let networkHandler = generateNetworkHandlerInstance()
//
//		var defaultRequest = dummyURL.request
//		defaultRequest.automaticStart = false
//		let defTask = networkHandler.transferMahOptionalDatas(with: defaultRequest, completion: { _ in })
//		XCTAssertEqual(defTask.priority, defaultRequest.priority)
//
//		var highRequest = dummyURL.request
//		highRequest.priority = .highPriority
//		highRequest.automaticStart = false
//		let highTask = networkHandler.transferMahOptionalDatas(with: highRequest, completion: { _ in })
//		XCTAssertEqual(highTask.priority, highRequest.priority)
//
//		var lowRequest = dummyURL.request
//		lowRequest.priority = .highPriority
//		lowRequest.automaticStart = false
//		let lowTask = networkHandler.transferMahOptionalDatas(with: lowRequest, completion: { _ in })
//		XCTAssertEqual(lowTask.priority, lowRequest.priority)
//
//		var arbitraryRequest = dummyURL.request
//		arbitraryRequest.priority = -1
//		XCTAssertEqual(0, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 0
//		XCTAssertEqual(0, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 0.4
//		XCTAssertEqual(0.4, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 1
//		XCTAssertEqual(1, arbitraryRequest.priority.rawValue)
//
//		arbitraryRequest.priority = 4
//		XCTAssertEqual(1, arbitraryRequest.priority.rawValue)
//	}
//
//	func testAutoStart() {
//		let dummyURL = URL(string: "https://redeggproductions.com")!
//		let networkHandler = generateNetworkHandlerInstance()
//
//		let defaultRequest = dummyURL.request
//		let startedTask = networkHandler.transferMahDatas(with: defaultRequest, completion: { _ in })
//		XCTAssertEqual(startedTask.status, .running)
//
//		var noStartRequest = dummyURL.request
//		noStartRequest.automaticStart = false
//		let noStart = networkHandler.transferMahDatas(with: noStartRequest, completion: { _ in })
//		XCTAssertEqual(noStart.status, .suspended)
//	}
//}

class MiscTest: XCTestCase {
	@available(iOS 15.0, *)
	func testThing() async throws {
		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/uploader.bin")!


		let theDelegate = MyDelegate()

		let session = URLSession(configuration: .default, delegate: theDelegate, delegateQueue: nil)

//		let result = try await session.data(from: url, delegate: theDelegate)
		let ex = expectation(description: "waiting")
		let task = session.dataTask(with: url)
		task.resume()

		wait(for: [ex], timeout: 1000)
//		print(result.0)
	}
}

import Combine
class MyDelegate: NSObject, URLSessionDataDelegate {
	var task: URLSessionTask?

	private var bag: Set<AnyCancellable> = []

	func trackTask(_ task: URLSessionTask) {
		guard self.task == nil else { return }

		self.task = task
//		task.progress
//			.publisher(for: \.fractionCompleted)
//			.sink { value in
//				print("progress: \(value)")
//			}
//			.store(in: &bag)
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error = error {
			print("completed with error: \(error)")
		} else {
			print("completed")
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		print("Redirected")
		completionHandler(request)
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		print("did send body data")
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		print("did get challenge: \(challenge)")
		trackTask(task)
		completionHandler(.performDefaultHandling, nil)
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
		print("Will begin delayed request")
		completionHandler(.continueLoading, request)
	}

	func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
		print("waiting for connectivitiy")
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
		print("got metrics")
		self.task = nil
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		print("got response: \(response)")
		if response.expectedContentLength > 1024 * 5 {
			completionHandler(.becomeDownload)
		} else {
			completionHandler(.allow)
		}
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		print("became stream task: \(streamTask)")
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		print("became download task: \(downloadTask)")
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		print("got some data: \(data)")
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
		print("will cache response")
		completionHandler(proposedResponse)
	}
}
