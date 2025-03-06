import Testing
import SwiftPizzaSnips
import NetworkHandler
import Logging
import Foundation
import PizzaMacros
import Crypto
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct NetworkHandlerCommonTests<Engine: NetworkEngine>: Sendable {
	#if canImport(AppKit)
	public typealias TestImage = NSImage
	#elseif canImport(UIKit)
	public typealias TestImage = UIImage
	#endif

	public let imageURL = #URL("https://s3.wasabisys.com/network-handler-tests/images/IMG_2932.jpg")
	public let demoModelURL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/demoModel.json")
	public let badDemoModelURL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/badDemoModel.json")
	public let demo404URL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/akjsdhjklahgdjkahsfjkahskldf.json")
	public let uploadURL = #URL("https://s3.wasabisys.com/network-handler-tests/uploader.bin")
	public let randomDataURL = #URL("https://s3.wasabisys.com/network-handler-tests/randomData.bin")

	public let logger: Logger

	public init(logger: Logger) {
		self.logger = logger
	}

	/// Tests downloading, caching the download, and subsequently loading the file from cache.
	/// performs a `GET` request to `imageURL`
	public func downloadAndCacheImages(
		engine: Engine,
		imageExpectationData: Data,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let rawStart = Date()
		let image1Result = try await nh.transferMahDatas(
			for: .download(imageURL.downloadRequest),
			usingCache: .key("kitten"),
			requestLogger: logger)
		let rawFinish = Date()

		let cacheStart = Date()
		let image2Result = try await nh.transferMahDatas(
			for: .download(imageURL.downloadRequest),
			usingCache: .key("kitten"),
			requestLogger: logger)
		let cacheFinish = Date()

		// calculate cache speed improvement, just for funsies
		let rawDuration = rawFinish.timeIntervalSince(rawStart)
		let cacheDuration = cacheFinish.timeIntervalSince(cacheStart)
		let cacheRatio = cacheDuration / rawDuration

		let formatter = NumberFormatter()
		formatter.maximumFractionDigits = 6
		let netDurationStr = formatter.string(from: rawDuration as NSNumber) ?? "nan"
		let cacheDurationStr = formatter.string(from: cacheDuration as NSNumber) ?? "nan"
		let cacheRatioStr = formatter.string(from: cacheRatio as NSNumber) ?? "nan"
		logger.info("netDuration: \(netDurationStr)\ncacheDuration: \(cacheDurationStr)\ncache took \(cacheRatioStr)x as long")
		#expect(
			cacheDuration < (rawDuration * 0.5),
			"The cache lookup wasn't even twice as fast as the original lookup. It's possible the cache isn't working",
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))

		let imageOneData = image1Result.data
		let imageTwoData = image2Result.data
		#expect(
			imageOneData == imageTwoData,
			"hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)",
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(
			imageOneData == imageExpectationData,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))

		#if canImport(AppKit) || canImport(UIKit)
		_ = try #require(
			TestImage(data: imageOneData),
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#endif
	}

	public func downloadAndDecodeData<D: Decodable & Sendable & Equatable>(
		engine: Engine,
		modelURL: URL,
		expectedModel: D,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let resultModel: D = try await nh.transferMahCodableDatas(
			for: .download(modelURL.downloadRequest),
			delegate: nil,
			requestLogger: logger).decoded

		#expect(
			expectedModel == resultModel,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `GET` request to `demo404URL`
	public func handle404Error<E: Error & Equatable>(
		engine: Engine,
		expectedError: E,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = demo404URL
		let originalRequest = NetworkRequest.download(url.downloadRequest)

		let resultModel: Result<String, Error> = await Task { [logger] in
			try await nh.transferMahCodableDatas(
				for: originalRequest,
				delegate: nil,
				requestLogger: logger).decoded
		}.result

		#expect(
			throws: expectedError,
			performing: {
			_ = try resultModel.get()
		})
	}

	/// performs a `GET` request to `demoModelURL`
	public func expect200OnlyGet200(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = demoModelURL
		let request = url.downloadRequest.with {
			$0.expectedResponseCodes = 200
		}
		_ = try await nh.transferMahDatas(
			for: .download(request),
			requestLogger: logger,
			onError: { _,_,_  in .throw })
	}

	/// performs a `POST` request to `demoModelURL`
	public func expect200OnlyGet201(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = demoModelURL
		let request = url.downloadRequest.with {
			$0.expectedResponseCodes = 200
			$0.method = .post
		}

		await #expect(
			performing: {
				_ = try await nh.transferMahDatas(
					for: .download(request),
					requestLogger: logger,
					onError: { _,_,_  in .throw })
			},
			throws: { error in
				guard
					let networkError = error as? NetworkError,
					case .httpUnexpectedStatusCode(code: let code, originalRequest: _, data: _) = networkError,
					code == 201
				else { return false }
				return true
			})
	}

	/// performs a `PUT` request to `uploadURL`
	public func uploadFileURL(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			throw SimpleTestError(message: "Need s3 credentials")
		}

		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let upRequest = uploadURL.uploadRequest.with {
			$0.method = .put
			$0.expectedResponseCodes = 201
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let hash = try fileHash(actualTestFile)

		let awsHeaderInfo = AWSV4Signature(
			for: upRequest,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(hash))

		let signedRequest = try awsHeaderInfo.processRequest(upRequest)

		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .localFile(actualTestFile))

		let dlRequest = uploadURL.downloadRequest

		let dlResult = try await nh.transferMahDatas(for: .download(dlRequest)).data
		#expect(
			SHA256.hash(data: dlResult) == hash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `PUT` request to `uploadURL`
	public func uploadMultipartFile(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			throw SimpleTestError(message: "Need s3 credentials")
		}

		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let upRequest = uploadURL.uploadRequest.with {
			$0.method = .put
			$0.expectedResponseCodes = 201
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let boundary = "akjlsdghkajshdg"
		let multipart = MultipartFormInputTempFile(boundary: boundary)
		multipart.addPart(named: "file", fileURL: actualTestFile, contentType: "application/octet-stream")

		let multipartFile = try await multipart.renderToFile()
		defer { try? FileManager.default.removeItem(at: multipartFile )}

		let multipartHash = try fileHash(multipartFile)

		let awsHeaderInfo = AWSV4Signature(
			for: upRequest,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(multipartHash))

		let signedRequest = try awsHeaderInfo.processRequest(upRequest)

		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .localFile(multipartFile))

		let dlRequest = uploadURL.downloadRequest

		let dlResult = try await nh.transferMahDatas(for: .download(dlRequest)).data
		#expect(
			SHA256.hash(data: dlResult) == multipartHash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `PUT` request to `uploadURL`
	public func uploadMultipartStream(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		guard
			TestEnvironment.s3AccessSecret.isEmpty == false,
			TestEnvironment.s3AccessKey.isEmpty == false
		else {
			throw SimpleTestError(message: "Need s3 credentials")
		}

		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let upRequest = uploadURL.uploadRequest.with {
			$0.method = .put
			$0.expectedResponseCodes = 201
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let boundary = "akjlsdghkajshdg"
		let multipart = MultipartFormInputStream(boundary: boundary)
		try multipart.addPart(named: "file", fileURL: actualTestFile, contentType: "application/octet-stream")

		let multipartHash = try streamHash(multipart.safeCopy())

		let awsHeaderInfo = AWSV4Signature(
			for: upRequest,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(multipartHash))

		let signedRequest = try awsHeaderInfo.processRequest(upRequest)

		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .inputStream(multipart))

		let dlRequest = uploadURL.downloadRequest

		let dlResult = try await nh.transferMahDatas(for: .download(dlRequest)).data
		#expect(
			SHA256.hash(data: dlResult) == multipartHash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `GET` request to `badDemoModelURL`. Provided must be corrupted in some way.
	public func badCodableData(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		await #expect(
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0),
			performing: {
				let _: DemoModel = try await nh.transferMahCodableDatas(
					for: .download(badDemoModelURL.downloadRequest),
					delegate: nil,
					requestLogger: logger).decoded
			},
			throws: {
				guard
					let networkError = $0 as? NetworkError,
					case .dataCodingError(specifically: _, sourceData: _) = networkError
				else { return false }
				return true
			})
	}

	/// performs a `GET` request to `badDemoModelURL`. Provided must be corrupted in some way.
	public func cancellationViaTask(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let request = randomDataURL.downloadRequest

		let forCancel = Task {
			let accumulated = AtomicValue(value: 0)
			let delegate = await Delegate(onResponseBodyProgress: { [accumulated] delegate, request, bodyData in
				accumulated.value += bodyData.count

				guard accumulated.value > 40960 else { return }
				withUnsafeCurrentTask { currentTask in
					currentTask?.cancel()
				}
			})

			return try await nh.transferMahDatas(for: .download(request), delegate: delegate)
		}

		await #expect(throws: NetworkError.requestCancelled, performing: {
			_ = try await forCancel.value
		})
	}

	// MARK: - Utilities
	private func getNetworkHandler(with engine: Engine) -> NetworkHandler<Engine> {
		let nh = NetworkHandler(name: "\(#fileID) - \(Engine.self)", engine: engine)
		nh.resetCache()
		return nh
	}

	private func createDummyFile(at url: URL, megabytes: Int, using rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) throws -> (file: URL, done: () throws -> Void) {
		let outFile = {
			var current = url
			while current.checkResourceIsAccessible() {
				let fileName = current.deletingPathExtension().lastPathComponent
				let newFilename = fileName + "_copy"
				current = current.deletingLastPathComponent().appending(component: newFilename).appendingPathExtension("bin")
			}
			return current
		}()
		guard
			let outputStream = OutputStream(url: outFile, append: false)
		else { throw SimpleTestError(message: "no output stream") }
		outputStream.open()
		defer { outputStream.close() }
		let length = 1024 * 1024
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
		defer { buffer.deallocate() }
		let raw = UnsafeMutableRawPointer(buffer)
		let quicker = raw.bindMemory(to: UInt64.self, capacity: length / 8)

		var rng = rng
		(0..<megabytes).forEach { _ in
			for index in 0..<(length / 8) {
				quicker[index] = UInt64.random(in: 0...UInt64.max, using: &rng)
			}

			_ = outputStream.write(buffer, maxLength: length)
		}

		let done = {
			try FileManager.default.removeItem(at: outFile)
		}
		return (outFile, done)
	}

	private func fileHash(_ url: URL) throws -> SHA256Digest {
		guard let input = InputStream(url: url) else { throw NSError(domain: "Error loading file for hashing", code: -1) }

		return try streamHash(input)
	}

	private func streamHash(_ input: InputStream) throws -> SHA256Digest {
		var hasher = SHA256()

		let bufferSize = 1024 // KB
		* 1024 // MB
		* 10 // MB count
		let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferSize)
		guard let pointer = buffer.baseAddress else { throw NSError(domain: "Error allocating buffer", code: -2) }
		input.open()
		while input.hasBytesAvailable {
			let bytesRead = input.read(pointer, maxLength: bufferSize)
			let bufferrr = UnsafeRawBufferPointer(start: pointer, count: bytesRead)
			hasher.update(bufferPointer: bufferrr)
		}
		input.close()

		return hasher.finalize()
	}
}

extension NetworkHandlerCommonTests {
	class Delegate: NetworkHandlerTaskDelegate {
		let onStart: @Sendable (_ delegate: Delegate, NetworkRequest) -> Void
		let onSendData: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ byteCountSent: Int, _ totalExpected: Int?) -> Void
		let onSendingFinish: @Sendable (_ delegate: Delegate, NetworkRequest) -> Void
		let onResponseHeader: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ header: EngineResponseHeader) -> Void
		let onResponseBodyProgress: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ bytes: Data) -> Void
		let onRequestFinished: @Sendable (_ delegate: Delegate, Error?) -> Void

		var stream: ResponseBodyStream?

		init(
			onStart: @escaping @Sendable (_ delegate: Delegate, NetworkRequest) -> Void = { _, _ in },
			onSendData: @escaping @Sendable (_ delegate: Delegate, _: NetworkRequest, _: Int, _: Int?) -> Void = { _, _, _, _ in },
			onSendingFinish: @escaping @Sendable (_ delegate: Delegate, NetworkRequest) -> Void = { _, _ in },
			onResponseHeader: @escaping @Sendable (_ delegate: Delegate, _: NetworkRequest, _: EngineResponseHeader) -> Void = { _, _, _ in },
			onResponseBodyProgress: @escaping @Sendable (_ delegate: Delegate, _: NetworkRequest, _: Data) -> Void = { _, _, _ in },
			onRequestFinished: @escaping @Sendable (_ delegate: Delegate, Error?) -> Void = { _, _ in }
		) {
			self.onStart = onStart
			self.onSendData = onSendData
			self.onSendingFinish = onSendingFinish
			self.onResponseHeader = onResponseHeader
			self.onResponseBodyProgress = onResponseBodyProgress
			self.onRequestFinished = onRequestFinished
		}

		func transferDidStart(for request: NetworkRequest) {
			onStart(self, request)
		}
		
		func sentData(for request: NetworkRequest, byteCountSent: Int, totalExpectedToSend: Int?) {
			onSendData(self, request, byteCountSent, totalExpectedToSend)
		}
		
		func sendingDataDidFinish(for request: NetworkRequest) {
			onSendingFinish(self, request)
		}
		
		func responseHeaderRetrieved(for request: NetworkRequest, header: EngineResponseHeader) {
			onResponseHeader(self, request, header)
		}
		
		func responseBodyReceived(for request: NetworkRequest, bytes: Data) {
			onResponseBodyProgress(self, request, bytes)
		}
		
		func responseBodyReceived(for request: NetworkRequest, byteCount: Int, totalExpectedToReceive: Int?) {}
		
		func requestFinished(withError error: (any Error)?) {
			onRequestFinished(self, error)
		}
	}
}
