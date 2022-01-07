@testable import NetworkHandler
import XCTest

class NetworkCacheTests: NetworkCacheTest {
	func testCacheCountLimit() {
		let cache = generateNetworkHandlerInstance().cache

		let initialLimit = cache.countLimit
		cache.countLimit = 5
		XCTAssertEqual(5, cache.countLimit)
		cache.countLimit = initialLimit
		XCTAssertEqual(initialLimit, cache.countLimit)
	}

	func testCacheTotalCostLimit() {
		let cache = generateNetworkHandlerInstance().cache

		let initialLimit = cache.totalCostLimit
		cache.totalCostLimit = 5
		XCTAssertEqual(5, cache.totalCostLimit)
		cache.totalCostLimit = initialLimit
		XCTAssertEqual(initialLimit, cache.totalCostLimit)
	}

	func testCacheName() {
		let cache = generateNetworkHandlerInstance().cache

		XCTAssertEqual("Test Network Handler-Cache", cache.name)
	}

	func testCacheAddRemove() {
		let data1 = Data([1, 2, 3, 4, 5])
		let data2 = Data(data1.reversed())

		let response1 = URLResponse(
			url: URL(string: "https://redeggproductions.com")!,
			mimeType: nil,
			expectedContentLength: 1024,
			textEncodingName: nil)
		let response2 = URLResponse(
			url: URL(string: "https://github.com")!,
			mimeType: nil,
			expectedContentLength: 2048,
			textEncodingName: nil)

		let cachedItem1 = NetworkCacheItem(response: response1, data: data1)
		let cachedItem2 = NetworkCacheItem(response: response2, data: data2)

		let networkHandler = generateNetworkHandlerInstance()
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
