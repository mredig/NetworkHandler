//
//  NetworkCacheTests.swift
//  NetworkHandler
//
//  Created by Michael Redig on 5/10/20.
//  Copyright © 2020 Red_Egg Productions. All rights reserved.
//

@testable import NetworkHandler
import XCTest

class NetworkDiskCacheTests: XCTestCase {

	static var dummy1MFile = Data(repeating: 0, count: 1024)
	static var dummy2MFile = Data(repeating: 0, count: 1024 * 2)
	static var dummy5MFile = Data(repeating: 0, count: 1024 * 5)

	static func fileAssortment() -> (
		(key: String, data: Data),
		(key: String, data: Data),
		(key: String, data: Data),
		(key: String, data: Data),
		(key: String, data: Data)
	) {
		let file1 = (key: "file1", data: Self.dummy1MFile)
		let file2 = (key: "file2", data: Self.dummy2MFile)
		let file3 = (key: "file3", data: Self.dummy5MFile)
		let file4 = (key: "file4", data: Self.dummy1MFile)
		let file5 = (key: "file5", data: Self.dummy1MFile)
		return (file1, file2, file3, file4, file5)
	}

	func testSetGet() {
		let cache = NetworkDiskCache()
		cache.resetCache()

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		cache.setData(file1.data, key: file1.key, sync: false)
		cache.setData(file2.data, key: file2.key, sync: false)
		cache.setData(file3.data, key: file3.key, sync: false)
		cache.setData(file4.data, key: file4.key, sync: false)

		let save = expectation(for: .init(block: { anyCache, _ in
			guard let cache = anyCache as? NetworkDiskCache else { return false }
			return !cache.isActive
		}), evaluatedWith: cache, handler: nil)

		wait(for: [save], timeout: 10)

		XCTAssertEqual(cache.getData(for: file1.key), file1.data)
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertEqual(cache.getData(for: file3.key), file3.data)
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))
	}

	func testReset() {
		let cache = generateDiskCache()

		let (file1, _, _, _, _) = Self.fileAssortment()

		cache.setData(file1.data, key: file1.key)

		waitForCacheToFinishActivity(cache)

		XCTAssertEqual(1024, cache.size)
		XCTAssertEqual(1, cache.count)

		cache.resetCache()

		XCTAssertEqual(0, cache.size)
		XCTAssertEqual(0, cache.count)
	}

	func testCacheCapacity() {
		let cache = NetworkDiskCache(capacity: 2048, cacheName: "2M Cache Test")

		let file1 = (key: "file1", data: Self.dummy1MFile)
		let file2 = (key: "file2", data: Self.dummy1MFile)
		let file3 = (key: "file3", data: Self.dummy1MFile)
		let file4 = (key: "file4", data: Self.dummy1MFile)

		cache.setData(file1.data, key: file1.key, sync: true)
	}

	func testCacheAddRemove() {
		let data1 = Data([1, 2, 3, 4, 5])
		let data2 = Data(data1.reversed())

		let cache = NetworkHandler().cache

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
		cache[key3] = nil
		XCTAssertNil(cache[key3])
		XCTAssertEqual(data1, cache[key2])
		XCTAssertEqual(data2, cache[key1])

		cache[key3] = data1
		XCTAssertEqual(data1, cache[key3])
		let removed = cache.remove(objectFor: key3)
		XCTAssertNil(cache[key3])
		XCTAssertEqual(data1, removed)

		cache.reset()
		XCTAssertNil(cache[key1])
		XCTAssertNil(cache[key2])
		XCTAssertNil(cache[key3])
	}

	private func waitForCacheToFinishActivity(_ cache: NetworkDiskCache, timeout: TimeInterval = 10) {
		let isActive = expectation(for: .init(block: { anyCache, _ in
			guard let cache = anyCache as? NetworkDiskCache else { return false }
			return !cache.isActive
		}), evaluatedWith: cache, handler: nil)

		wait(for: [isActive], timeout: timeout)
	}

	private func generateDiskCache(named name: String? = nil) -> NetworkDiskCache {
		let cache = NetworkDiskCache(cacheName: name)

		let reset = expectation(for: .init(block: { anyCache, _ in
			guard let cache = anyCache as? NetworkDiskCache else { return false }
			return !cache.isActive
		}), evaluatedWith: cache, handler: nil)

		wait(for: [reset], timeout: 10)

		cache.resetCache()
		return cache
	}

}
