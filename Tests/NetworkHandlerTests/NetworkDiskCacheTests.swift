@testable import NetworkHandler
import XCTest
import Logging
import NetworkHandlerMockingEngine

class NetworkDiskCacheTests: NetworkCacheTest {

	nonisolated(unsafe)
	static var dummy1KFile = Data(repeating: 0, count: 1024)
	nonisolated(unsafe)
	static var dummy2KFile = Data(repeating: 0, count: 1024 * 2)
	nonisolated(unsafe)
	static var dummy5KFile = Data(repeating: 0, count: 1024 * 5)

	// swiftlint:disable:next large_tuple
	static func fileAssortment() -> (
		file1: (key: String, data: Data),
		file2: (key: String, data: Data),
		file3: (key: String, data: Data),
		file4: (key: String, data: Data),
		file5: (key: String, data: Data)
	) {
		let file1 = (key: "file1", data: Self.dummy1KFile)
		let file2 = (key: "file2", data: Self.dummy2KFile)
		let file3 = (key: "file3", data: Self.dummy5KFile)
		let file4 = (key: "file4", data: Self.dummy1KFile)
		let file5 = (key: "file5", data: Self.dummy1KFile)
		return (file1, file2, file3, file4, file5)
	}

	override func tearDown() {
		let cache = generateDiskCache()
		cache.resetCache()
	}

	func testCacheAddRemove() {
		let logger = Logger(label: #function)
		let cache = NetworkDiskCache(logger: logger)
		cache.resetCache()

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		cache.setData(file1.data, key: file1.key, sync: false)
		cache.setData(file2.data, key: file2.key, sync: false)
		cache.setData(file3.data, key: file3.key, sync: false)
		cache.setData(file4.data, key: file4.key, sync: false)

		let save = expectation(
			for: .init(
				block: { anyCache, _ in
					guard let cache = anyCache as? NetworkDiskCache else { return false }
					return !cache.isActive
				}),
			evaluatedWith: cache,
			handler: nil)

		wait(for: [save], timeout: 10)

		XCTAssertEqual(cache.getData(for: file1.key), file1.data)
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertEqual(cache.getData(for: file3.key), file3.data)
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))

		cache.deleteData(for: file1.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertEqual(cache.getData(for: file3.key), file3.data)
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))

		cache.deleteData(for: file3.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertNil(cache.getData(for: file3.key))
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))
	}

	func testReset() {
		let cache = generateDiskCache()

		let file1 = Self.fileAssortment().file1

		cache.setData(file1.data, key: file1.key)

		waitForCacheToFinishActivity(cache)

		XCTAssertEqual(1024, cache.size)
		XCTAssertEqual(1, cache.count)

		cache.resetCache()

		XCTAssertEqual(0, cache.size)
		XCTAssertEqual(0, cache.count)
	}

	func testCacheCapacity() {
		let cache = generateDiskCache()
		cache.capacity = 1024 * 2

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		cache.setData(file1.data, key: file1.key, sync: true)
		XCTAssertEqual(file1.data, cache.getData(for: file1.key))

		cache.setData(file2.data, key: file2.key, sync: true)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertEqual(file2.data, cache.getData(for: file2.key))

		cache.setData(file3.data, key: file3.key, sync: true)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertNil(cache.getData(for: file2.key))
		XCTAssertNil(cache.getData(for: file3.key))

		cache.setData(file4.data, key: file4.key, sync: true)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertNil(cache.getData(for: file2.key))
		XCTAssertNil(cache.getData(for: file3.key))
		XCTAssertEqual(file4.data, cache.getData(for: file4.key))

		cache.setData(file5.data, key: file5.key, sync: true)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertNil(cache.getData(for: file2.key))
		XCTAssertNil(cache.getData(for: file3.key))
		XCTAssertEqual(file4.data, cache.getData(for: file4.key))
		XCTAssertEqual(file5.data, cache.getData(for: file5.key))

	}
}
