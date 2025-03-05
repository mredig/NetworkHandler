import Testing
import SwiftPizzaSnips
import NetworkHandler
import Logging
import Foundation
import PizzaMacros
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct NetworkHandlerCommonTests<Engine: NetworkEngine> {
	#if canImport(AppKit)
	public typealias TestImage = NSImage
	#elseif canImport(UIKit)
	public typealias TestImage = UIImage
	#endif

	public let imageURL = #URL("https://s3.wasabisys.com/network-handler-tests/images/IMG_2932.jpg")
	public let demoModelURL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/demoModel.json")
	public let demo404URL = #URL("https://s3.wasabisys.com/network-handler-tests/coding/akjsdhjklahgdjkahsfjkahskldf.json")

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
			sourceLocation: SourceLocation(fileID: file, filePath: file, line: line, column: 0))

		let imageOneData = image1Result.data
		let imageTwoData = image2Result.data
		#expect(
			imageOneData == imageTwoData,
			"hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)",
			sourceLocation: SourceLocation(fileID: file, filePath: file, line: line, column: 0))
		#expect(
			imageOneData == imageExpectationData,
			sourceLocation: SourceLocation(fileID: file, filePath: file, line: line, column: 0))

		#if canImport(AppKit) || canImport(UIKit)
		_ = try #require(
			TestImage(data: imageOneData),
			sourceLocation: SourceLocation(fileID: file, filePath: file, line: line, column: 0))
		#endif
	}

	public func downloadAndDecodeData<D: Decodable & Sendable & Equatable>(
		engine: Engine,
		modelURL: URL,
		expectedModel: D,
		file: String = #fileID,
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
			sourceLocation: SourceLocation(fileID: file, filePath: file, line: line, column: 0))
	}

	/// performs a `GET` request to `demo404URL`
	public func handle404Error<E: Error & Equatable>(
		engine: Engine,
		expectedError: E,
		file: String = #fileID,
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

	private func getNetworkHandler(with engine: Engine) -> NetworkHandler<Engine> {
		let nh = NetworkHandler(name: "\(#fileID) - \(Engine.self)", engine: engine)
		nh.resetCache()
		return nh
	}
}
