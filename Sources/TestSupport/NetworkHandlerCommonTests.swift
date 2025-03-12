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

	public let imageURL = #URL("https://s3.wasabisys.com/network-handler-tests/images/lighthouse.jpg")
	public let demoModelURL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/demoModel.json")
	public let badDemoModelURL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/badDemoModel.json")
	public let demo404URL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/akjsdhjklahgdjkahsfjkahskldf.json")
	public let uploadURL = #URL("https://s3.wasabisys.com/network-handler-tests/uploader.bin")
	public let randomDataURL = #URL("https://s3.wasabisys.com/network-handler-tests/randomData.bin")
	public let chonkURL = #URL("https://s3.wasabisys.com/network-handler-tests/chonk.bin")
	public let echoURL = #URL("https://echo.free.beeceptor.com/")

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
		let image1Result = try await nh.downloadMahDatas(
			for: imageURL.downloadRequest,
			usingCache: .key("kitten"),
			requestLogger: logger)
		let rawFinish = Date()

		let cacheStart = Date()
		let image2Result = try await nh.downloadMahDatas(
			for: imageURL.downloadRequest,
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
			imageOneData.flatMap { TestImage(data: $0) },
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

		let resultModel: D = try await nh.downloadMahCodableDatas(
			for: modelURL.downloadRequest,
			delegate: nil,
			requestLogger: logger).decoded

		#expect(
			expectedModel == resultModel,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `GET` request to `chonkURL`
	public func downloadFile(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = chonkURL
		let request = url.downloadRequest

		let outputFileURL = URL.temporaryDirectory.appending(component: "downloadfile").appendingPathExtension("test")
		let tempFileURL = URL.temporaryDirectory.appending(components: UUID().uuidString)

		#expect(outputFileURL.checkResourceIsAccessible() == false)
		#expect(tempFileURL.checkResourceIsAccessible() == false)

		defer {
			try? FileManager.default.removeItem(at: outputFileURL)
			try? FileManager.default.removeItem(at: tempFileURL)
		}

		try await confirmation { tempFileExisted in
			Task {
				var seen = false
				while seen == false {
					try await Task.sleep(for: .milliseconds(20))
					guard tempFileURL.checkResourceIsAccessible() else { continue }
					seen = true
					tempFileExisted()
				}
			}

			_ = try await nh.downloadMahFile(
				for: request,
				savingToLocalFileURL: outputFileURL,
				withTemporaryFile: tempFileURL,
				requestLogger: logger)
		}

		let fileHash = try fileHash(outputFileURL)
		#expect(fileHash.toHexString() == "92b640d348a4627b4185f5378d8949b542055bd37fe513e6add9a1e010a3a83d")
		#expect(outputFileURL.checkResourceIsAccessible())
		#expect(tempFileURL.checkResourceIsAccessible() == false)
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

		let resultModel: Result<String, Error> = await Task { [logger] in
			try await nh.downloadMahCodableDatas(
				for: url.downloadRequest,
				delegate: nil,
				requestLogger: logger).decoded
		}.result

		#expect(
			performing: {
				_ = try resultModel.get()
			},
			throws: {
				guard
					let error = $0 as? NetworkError,
					case .httpUnexpectedStatusCode(code: let code, originalRequest: _, data: _) = error
				else { return false }
				guard
					code == 404
				else { return false }

				return true
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
	public func expect201OnlyGet200(
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

		let payloadData = Data(##"{"id":"59747267-D47D-47CD-9E54-F79FA3C1F99B","imageURL":"https://s3.wasabisys.com/network-handler-tests/images/lighthouse.jpg","subtitle":"BarSub","title":"FooTitle"}"##.utf8)
		let url = demoModelURL
		let request = url.downloadRequest.with {
			$0.expectedResponseCodes = 201
			$0.method = .put
			$0.payload = payloadData
		}

		let hash = SHA256.hash(data: payloadData)

		let awsHeaderInfo = AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(hash))

		let signedRequest = try awsHeaderInfo.processRequest(request)

		await #expect(
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0),
			performing: {
				_ = try await nh.transferMahDatas(
					for: .download(signedRequest),
					requestLogger: logger,
					onError: { _,_,_  in .throw })
			},
			throws: { error in
				guard
					let networkError = error as? NetworkError,
					case .httpUnexpectedStatusCode(code: let code, originalRequest: _, data: _) = networkError,
					code == 200
				else { return false }
				return true
			})
	}

	/// performs a `PUT` request to `randomDataURL`. Provided must be corrupted in some way.
	public func uploadData(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = randomDataURL
		let request = url.uploadRequest.with {
			$0.method = .put
		}

		let sizeOfUploadMB: UInt8 = 5
		let fileSize = Int(sizeOfUploadMB) * 1024 * 1024

		var rng: any RandomNumberGenerator = SeedableRNG(seed: 349687)
		let randomData = Data.random(count: fileSize, using: &rng)

		let dataHash = SHA256.hash(data: randomData)
		print(dataHash)

		let awsHeaderInfo = AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(dataHash))

		let signedRequest = try awsHeaderInfo.processRequest(request)

		let atomicRequest = AtomicValue(value: NetworkRequest.upload(signedRequest, payload: .data(randomData)))
		let delegate = await Delegate(onRequestModified: { del, orig, new in
			atomicRequest.value = new
		})

		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .data(randomData), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength != nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))

		let dlRequest = url.downloadRequest

		let dlResult = try await nh.downloadMahDatas(for: dlRequest).data
		#expect(
			SHA256.hash(data: dlResult!) == dataHash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
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

		let url = uploadURL
		let upRequest = url.uploadRequest.with {
			$0.method = .put
			$0.expectedResponseCodes = 200
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

		let atomicRequest = AtomicValue(value: NetworkRequest.upload(signedRequest, payload: .localFile(actualTestFile)))
		let delegate = await Delegate(onRequestModified: { del, orig, new in
			atomicRequest.value = new
		})
		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .localFile(actualTestFile), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength != nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))

		let dlRequest = url.downloadRequest

		let dlResult = try await nh.transferMahDatas(for: .download(dlRequest)).data
		#expect(
			SHA256.hash(data: dlResult!) == hash,
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
			$0.expectedResponseCodes = 200
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

		let atomicRequest = AtomicValue(value: NetworkRequest.upload(signedRequest, payload: .localFile(multipartFile)))
		let delegate = await Delegate(onRequestModified: { del, orig, new in
			atomicRequest.value = new
		})
		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .localFile(multipartFile), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength != nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))

		let dlRequest = uploadURL.downloadRequest

		let dlResult = try await nh.transferMahDatas(for: .download(dlRequest)).data
		#expect(
			SHA256.hash(data: dlResult!) == multipartHash,
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
			$0.expectedResponseCodes = 200
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

		let atomicRequest = AtomicValue(value: NetworkRequest.upload(signedRequest, payload: .inputStream(multipart)))
		let delegate = await Delegate(onRequestModified: { del, orig, new in
			atomicRequest.value = new
		})
		_ = try await nh.uploadMahDatas(for: signedRequest, payload: .inputStream(multipart), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength == nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))

		let dlRequest = uploadURL.downloadRequest

		let dlResult = try await nh.transferMahDatas(for: .download(dlRequest)).data
		#expect(
			SHA256.hash(data: dlResult!) == multipartHash,
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
				let _: DemoModel = try await nh.downloadMahCodableDatas(
					for: badDemoModelURL.downloadRequest,
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

	/// performs a `GET` request to `randomDataURL`. Provided must be corrupted in some way.
	public func cancellationViaToken(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let request = randomDataURL.downloadRequest

		let cancelToken = NetworkCancellationToken()
		let forCancel = Task {
			let accumulated = AtomicValue(value: 0)
			let delegate = await Delegate(onResponseBodyProgress: { [accumulated] delegate, request, bodyData in
				accumulated.value += bodyData.count

				guard accumulated.value > 40960 else { return }
				cancelToken.cancel()
			})

			return try await nh.transferMahDatas(for: .download(request), delegate: delegate, cancellationToken: cancelToken)
		}

		await #expect(throws: NetworkError.requestCancelled, performing: {
			_ = try await forCancel.value
		})
	}

	/// performs a `GET` request to `randomDataURL`. Provided must be corrupted in some way.
	public func cancellationViaStream(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let request = randomDataURL.downloadRequest

		let stream = try await nh.streamMahDatas(for: .download(request)).stream

		let forCancel = Task {
			var accumulated = Data()
			for try await chunk in stream {
				accumulated.append(contentsOf: chunk)
				guard accumulated.count > 40960 else { continue }
				stream.cancel()
			}
		}

		await #expect(throws: NetworkError.requestCancelled, performing: {
			_ = try await forCancel.value
		})
	}

	/// performs a `PUT` request to `badDemoModelURL`. Provided must be corrupted in some way.
	public func uploadCancellationViaToken(
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

		let request = uploadURL.uploadRequest.with {
			$0.method = .put
		}

		var rng: RandomNumberGenerator = SeedableRNG(seed: 9345867)
		let randomData = Data.random(count: 1024 * 1024 * 10, using: &rng)

		let hash = SHA256.hash(data: randomData)

		let awsHeaderInfo = AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(hash))

		let signedRequest = try awsHeaderInfo.processRequest(request)
		let token = NetworkCancellationToken()

		let task = Task {
			let delegate = await Delegate(onSendData: { delegate, request, bytesSent, totalExpected in
				guard bytesSent > (1024 * 1024 * 2) else { return }
				token.cancel()
			})

			return try await nh.uploadMahDatas(
				for: signedRequest,
				payload: .data(randomData),
				delegate: delegate,
				cancellationToken: token)
		}

		await #expect(
			throws: NetworkError.requestCancelled,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0),
			performing: {
				_ = try await task.value
			})
	}

	/// performs a `PUT` request to `randomDataURL`. Provided must be corrupted in some way.
	public func timeoutTriggersRetry(
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

		let url = randomDataURL
		let request = url.uploadRequest.with {
			$0.method = .put
			$0.timeoutInterval = 0.001
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let hash = try fileHash(actualTestFile)

		let awsHeaderInfo = AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(hash))

		let signedRequest = try awsHeaderInfo.processRequest(request)

		let atomicFailCount = AtomicValue(value: 0)
		let expectedFailCount = 3

		await #expect(
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0),
			performing: {
				_ = try await nh.uploadMahDatas(for: signedRequest, payload: .localFile(actualTestFile), onError: { req, failCount, error in
					#expect(error.isCancellation() == false)
					print(error)
					atomicFailCount.value = failCount
					guard failCount < expectedFailCount else { return .throw }
					return .retry
				})
			},
			throws: {
				guard let error = $0 as? NetworkError else { return false }

				switch error {
				case .httpUnexpectedStatusCode:
					return false
				default:
					return true
				}

			})
		#expect(atomicFailCount.value == expectedFailCount, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `PUT` request to `randomDataURL` (only really useful to test with `MockingEngine`)
	public func retryOptions(
		engine: Engine,
		retryOption: NetworkHandler<Engine>.RetryOption,
		anticipatedOutput: Result<(header: EngineResponseHeader, data: Data), NetworkError>,
		expectedAttemptCount: Int,
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

		let url = randomDataURL
		let request = url.uploadRequest.with {
			$0.method = .put
		}

		var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
		let data = Data.random(count: 128, using: &rng)

		let hash = SHA256.hash(data: data)

		let awsHeaderInfo = AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(hash))

		let signedRequest = try awsHeaderInfo.processRequest(request)

		let atomicFailCount = AtomicValue(value: 0)

		switch anticipatedOutput {
		case .success(let success):
			let (header, data) = try await nh.uploadMahDatas(
				for: signedRequest,
				payload: .data(data)) { req, attempt, error in
					atomicFailCount.value = attempt
					if attempt == 1 {
						return retryOption
					} else {
						return .throw
					}
				}

			#expect(
				success.data == data,
				sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
			#expect(
				success.header == header,
				sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		case .failure(let failure):
			await #expect(throws: failure, performing: {
				_ = try await nh.uploadMahDatas(
					for: signedRequest,
					payload: .data(data),
					onError: { req, attempt, error in
						atomicFailCount.value = attempt
						if attempt == 1 {
							return retryOption
						} else {
							return .throw
						}
					})
			})
		}

		#expect(atomicFailCount.value == expectedAttemptCount, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `GET` request to `randomDataURL`. Provided must be corrupted in some way.
	public func downloadProgressTracking(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = randomDataURL
		let request = url.downloadRequest

		let accumulator = AtomicValue(value: [Int]())
		let expectedTotalAtomic = AtomicValue(value: 0)
		let delegate = await Delegate(onResponseBodyProgressCount: { del, request, count, expectedTotal in
			accumulator.value.append(count)
			if let expectedTotal {
				expectedTotalAtomic.value = expectedTotal
			}
			print("\(count) of \(expectedTotal ?? -1)")
		})

		let header = try await nh.downloadMahDatas(
			for: request,
			delegate: delegate).responseHeader

		#expect(header.expectedContentLength != nil, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(header.expectedContentLength.map(Int.init) == expectedTotalAtomic.value, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(accumulator.value.isOccupied, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(accumulator.value.sorted() == accumulator.value, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `PUT` request to `randomDataURL`. Provided must be corrupted in some way.
	public func uploadProgressTracking(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = randomDataURL
		let request = url.uploadRequest.with {
			$0.method = .put
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let hash = try fileHash(actualTestFile)

		let awsHeaderInfo = AWSV4Signature(
			for: request,
			awsKey: TestEnvironment.s3AccessKey,
			awsSecret: TestEnvironment.s3AccessSecret,
			awsRegion: .usEast1,
			awsService: .s3,
			hexContentHash: .fromShaHashDigest(hash))

		let signedRequest = try awsHeaderInfo.processRequest(request)

		let accumulator = AtomicValue(value: [Int]())
		let expectedTotalAtomic = AtomicValue(value: -1)
		let updatedRequestAtomic = AtomicValue(value: NetworkRequest.upload(signedRequest, payload: .localFile(testFileURL)))
		let delegate = await Delegate(
			onRequestModified: { delegate, originalReq, modReq in
				updatedRequestAtomic.value = modReq
			},
			onSendData: { del, request, count, expectedTotal in
				accumulator.value.append(count)
				if let expectedTotal {
					expectedTotalAtomic.value = expectedTotal
				}
				print("\(count) of \(expectedTotalAtomic.value)")
			})

		let _ = try await nh.uploadMahDatas(for: signedRequest, payload: .localFile(testFileURL), delegate: delegate)

		#expect(updatedRequestAtomic.value.headers[.contentLength] != nil, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(updatedRequestAtomic.value.headers[.contentLength].flatMap { Int($0.rawValue) } == expectedTotalAtomic.value, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(accumulator.value.isOccupied, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
		#expect(accumulator.value.sorted() == accumulator.value, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: 0))
	}

	/// performs a `GET` request to `echoURL`. Provided must be corrupted in some way.
	public func polling(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = echoURL
		let request = url.downloadRequest

		let echo: BeeEchoModel = try await nh.poll(
			request: .download(request),
			requestLogger: logger,
			until: { pollRequest, pollResult in
				do {
					let (header, beeEcho) = try pollResult.get()
					guard beeEcho.pathValue == 3 else {
						let nextIteration = (beeEcho.pathValue ?? 0) + 1
						let newRequest = pollRequest.with {
							var newURL = $0.url
							if newURL.path(percentEncoded: false).count > 1 {
								newURL.deleteLastPathComponent()
							}
							newURL.append(component: "\(nextIteration)")
							$0.url = newURL
						}
						return .continue(newRequest, 0.016)
					}
					return .finish(.success((header, beeEcho)))
				} catch {
					return .finish(.failure(error))
				}
			}).result

		#expect(echo.pathValue == 3)
	}

	public struct BeeEchoModel: Codable, Sendable {
		public let path: String

		public var pathValue: Int? {
			let num = path.drop(while: { $0.isNumber == false })
			return Int(num)
		}

		public init(path: String) {
			self.path = path
		}
	}

	// MARK: - Utilities
	private func getNetworkHandler(with engine: Engine, function: String = #function) -> NetworkHandler<Engine> {
		let nh = NetworkHandler(name: "\(#fileID) - \(Engine.self) (\(function))", engine: engine)
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
		let onRequestModified: @Sendable (_ delegate: Delegate, _ original: NetworkRequest, _ modified: NetworkRequest) -> Void
		let onStart: @Sendable (_ delegate: Delegate, NetworkRequest) -> Void
		let onSendData: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ totalByteCountSent: Int, _ totalExpected: Int?) -> Void
		let onSendingFinish: @Sendable (_ delegate: Delegate, NetworkRequest) -> Void
		let onResponseHeader: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ header: EngineResponseHeader) -> Void
		let onResponseBodyProgress: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ bytes: Data) -> Void
		let onResponseBodyProgressCount: @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ byteCount: Int, _ expectedTotal: Int?) -> Void
		let onRequestFinished: @Sendable (_ delegate: Delegate, Error?) -> Void

		init(
			onRequestModified: @escaping @Sendable (_ delegate: Delegate, _ original: NetworkRequest, _ modified: NetworkRequest) -> Void = { _, _, _ in },
			onStart: @escaping @Sendable (_ delegate: Delegate, NetworkRequest) -> Void = { _, _ in },
			onSendData: @escaping @Sendable (_ delegate: Delegate, _: NetworkRequest, _: Int, _: Int?) -> Void = { _, _, _, _ in },
			onSendingFinish: @escaping @Sendable (_ delegate: Delegate, NetworkRequest) -> Void = { _, _ in },
			onResponseHeader: @escaping @Sendable (_ delegate: Delegate, _: NetworkRequest, _: EngineResponseHeader) -> Void = { _, _, _ in },
			onResponseBodyProgress: @escaping @Sendable (_ delegate: Delegate, _: NetworkRequest, _: Data) -> Void = { _, _, _ in },
			onResponseBodyProgressCount: @escaping @Sendable (_ delegate: Delegate, _ request: NetworkRequest, _ byteCount: Int, _ expectedTotal: Int?) -> Void = { _, _, _, _ in},
			onRequestFinished: @escaping @Sendable (_ delegate: Delegate, Error?) -> Void = { _, _ in }
		) {
			self.onRequestModified = onRequestModified
			self.onStart = onStart
			self.onSendData = onSendData
			self.onSendingFinish = onSendingFinish
			self.onResponseHeader = onResponseHeader
			self.onResponseBodyProgress = onResponseBodyProgress
			self.onResponseBodyProgressCount = onResponseBodyProgressCount
			self.onRequestFinished = onRequestFinished
		}

		func requestModified(from oldVersion: NetworkRequest, to newVersion: NetworkRequest) {
			onRequestModified(self, oldVersion, newVersion)
		}

		func transferDidStart(for request: NetworkRequest) {
			onStart(self, request)
		}
		
		func sentData(for request: NetworkRequest, totalByteCountSent: Int, totalExpectedToSend: Int?) {
			onSendData(self, request, totalByteCountSent, totalExpectedToSend)
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
		
		func responseBodyReceived(for request: NetworkRequest, byteCount: Int, totalExpectedToReceive: Int?) {
			onResponseBodyProgressCount(self, request, byteCount, totalExpectedToReceive)
		}
		
		func requestFinished(withError error: (any Error)?) {
			onRequestFinished(self, error)
		}
	}
}
