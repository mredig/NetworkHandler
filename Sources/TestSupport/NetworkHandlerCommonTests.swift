import Testing
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

	public let logger: Logger

	public init(logger: Logger) {
		self.logger = logger
	}

	public func downloadAndCacheImages(
		engine: Engine,
		imageExpectationData: Data,
		file: String = #fileID,
		line: Int = #line,
		function: String = #function
	) async throws {
		let nh = NetworkHandler(name: "\(#fileID) - \(Engine.self)", engine: engine)
		nh.resetCache()
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
		#expect(cacheDuration < (rawDuration * 0.5), "The cache lookup wasn't even twice as fast as the original lookup. It's possible the cache isn't working")

		let imageOneData = image1Result.data
		let imageTwoData = image2Result.data
		#expect(imageOneData == imageTwoData, "hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)")
		#expect(imageOneData == imageExpectationData)

		#if canImport(AppKit) || canImport(UIKit)
		_ = try #require(TestImage(data: imageOneData))
		#endif
	}
}
