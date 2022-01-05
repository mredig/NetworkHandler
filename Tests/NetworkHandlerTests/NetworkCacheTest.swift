@testable import NetworkHandler
import XCTest
import TestSupport

class NetworkCacheTest: NetworkHandlerBaseTest {
	func waitForCacheToFinishActivity(_ cache: NetworkDiskCache, timeout: TimeInterval = 10) {
		let isActive = expectation(for: .init(block: { anyCache, _ in
			guard let cache = anyCache as? NetworkDiskCache else { return false }
			return !cache.isActive
		}), evaluatedWith: cache, handler: nil)

		wait(for: [isActive], timeout: timeout)
	}

	func generateDiskCache(named name: String? = nil) -> NetworkDiskCache {
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
