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

		let cache = generateNetworkHandlerInstance().cache
		let diskCache = cache.diskCache

		let key1 = URL(fileURLWithPath: "/").absoluteString
		let key2 = URL(fileURLWithPath: "/etc").absoluteString
		let key3 = URL(fileURLWithPath: "/usr").absoluteString

		cache[key1] = data1
		XCTAssertEqual(data1, cache[key1])
		cache[key1] = data2
		XCTAssertEqual(data2, cache[key1])

		cache[key2] = data1
		XCTAssertEqual(data1, cache[key2])
		XCTAssertEqual(data2, cache[key1])

		cache[key3] = data1
		XCTAssertEqual(data1, cache[key3])
		waitForCacheToFinishActivity(diskCache)
		cache[key3] = nil
		XCTAssertNil(cache[key3])
		XCTAssertEqual(data1, cache[key2])
		XCTAssertEqual(data2, cache[key1])

		cache[key3] = data1
		XCTAssertEqual(data1, cache[key3])
		waitForCacheToFinishActivity(diskCache)
		let removed = cache.remove(objectFor: key3)
		XCTAssertNil(cache[key3])
		XCTAssertEqual(data1, removed)

		cache.reset()
		XCTAssertNil(cache[key1])
		XCTAssertNil(cache[key2])
		XCTAssertNil(cache[key3])
	}

}
