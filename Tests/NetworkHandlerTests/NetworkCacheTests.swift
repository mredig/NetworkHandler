@testable import NetworkHandler
import XCTest
import PizzaMacros
import NetworkHandlerMockingEngine

class NetworkCacheTests: NetworkCacheTest {
	private let mockingEngine = MockingEngine()

	func testCacheCountLimit() {
		let cache = generateNetworkHandlerInstance(engine: mockingEngine).cache

		let initialLimit = cache.countLimit
		cache.countLimit = 5
		XCTAssertEqual(5, cache.countLimit)
		cache.countLimit = initialLimit
		XCTAssertEqual(initialLimit, cache.countLimit)
	}

	func testCacheTotalCostLimit() {
		let cache = generateNetworkHandlerInstance(engine: mockingEngine).cache

		let initialLimit = cache.totalCostLimit
		cache.totalCostLimit = 5
		XCTAssertEqual(5, cache.totalCostLimit)
		cache.totalCostLimit = initialLimit
		XCTAssertEqual(initialLimit, cache.totalCostLimit)
	}

	func testCacheName() {
		let cache = generateNetworkHandlerInstance(engine: mockingEngine).cache

		XCTAssertEqual("Test Network Handler-Cache", cache.name)
	}

	/// I've determined that NSCache's version of thread safety is that it doesn't block, so there are times that you might set a value, checking that it exists
	/// immediately afterwards only to find it's not there... But it will show up eventually. This, natually, messes with tests and causes this test to be unreliable.
	/// I'm working on finding a workaround to test, but in the meantime, this test failing isn't considered a real fail.
	///
	/// see idea in NetworkCache class
	func testCacheAddRemove() {
		let data1 = Data([1, 2, 3, 4, 5])
		let data2 = Data(data1.reversed())

		let response1 = EngineResponseHeader(
			status: 200,
			url: #URL("https://redeggproductions.com"),
			headers: [
				.contentLength: "\(1024)"
			])
		let response2 = EngineResponseHeader(
			status: 200,
			url: #URL("https://github.com"),
			headers: [
				.contentLength: "\(2048)"
			])

		let cachedItem1 = NetworkCacheItem(response: response1, data: data1)
		let cachedItem2 = NetworkCacheItem(response: response2, data: data2)

		let networkHandler = generateNetworkHandlerInstance(engine: mockingEngine)
		let cache = networkHandler.cache
		let diskCache = cache.diskCache

		let key1 = URL(fileURLWithPath: "/").absoluteString
		let key2 = URL(fileURLWithPath: "/etc").absoluteString
		let key3 = URL(fileURLWithPath: "/usr").absoluteString

		cache[key1] = cachedItem1
		XCTAssertEqual(cachedItem1.data, cache[key1]?.data)
		cache[key1] = cachedItem2
		XCTAssertEqual(cachedItem2.data, cache[key1]?.data)

		cache[key2] = cachedItem1
		XCTAssertEqual(cachedItem1.data, cache[key2]?.data)
		XCTAssertEqual(cachedItem2.data, cache[key1]?.data)

		cache[key3] = cachedItem1
		XCTAssertEqual(cachedItem1.data, cache[key3]?.data)
		waitForCacheToFinishActivity(diskCache)
		cache[key3] = nil
		XCTAssertNil(cache[key3])
		XCTAssertEqual(cachedItem1.data, cache[key2]?.data)
		XCTAssertEqual(cachedItem2.data, cache[key1]?.data)

		cache[key3] = cachedItem1
		XCTAssertEqual(cachedItem1.data, cache[key3]?.data)
		waitForCacheToFinishActivity(diskCache)
		let removed = cache.remove(objectFor: key3)
		XCTAssertNil(cache[key3])
		XCTAssertEqual(cachedItem1.data, removed?.data)

		cache.reset()
		XCTAssertNil(cache[key1])
		XCTAssertNil(cache[key2])
		XCTAssertNil(cache[key3])
	}
}
