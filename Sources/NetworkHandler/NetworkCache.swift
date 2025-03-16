import Foundation
import Logging

// swiftlint:disable line_length
/*
Idea to resolve non blocking issue in [this test](test://com.apple.xcode/NetworkHandler/NetworkHandlerTests/NetworkCacheTests/testCacheAddRemove)

create a cache-cache. Create a dict that stores the value right away, (using a lock for thread safety). then periodically check if the backing cache value is populated.
once it's populated, clear from the cache-cache. in the meantime, the cache-cache can serve up the content
*/
// swiftlint:enable line_length

/// Essentially just a wrapper for NSCache, but adds redundancy in a disk cache. Specifically purposed for
/// use with NetworkHandler
class NetworkCache {
	// MARK: - Properties
	private let cache = NSCache<NSString, NetworkCacheItem>()
	let diskCache: NetworkDiskCache
	private static let diskEncoder = PropertyListEncoder()
	private static let diskDecoder = PropertyListDecoder()

	/// The maximum number of objects the cache should hold.
	///
	/// If 0, there is no count limit. The default value is 0.
	/// This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly,
	/// later, or possibly never, depending on the implementation details of the cache.
	public var countLimit: Int {
		get { cache.countLimit }
		set { cache.countLimit = newValue }
	}

	/// The maximum total cost that the cache can hold before it starts evicting objects.
	///
	/// If `0`, there is no total cost limit. The default value is `0`.
	/// When you add an object to the cache, you may pass in a specified cost for the object, such as the size
	/// in bytes of the object. If adding this object to the cache causes the cache’s total cost to rise above
	/// `totalCostLimit`, the cache may automatically evict objects until its total cost falls below
	/// `totalCostLimit`. The order in which the cache evicts objects is not guaranteed. This is not a
	///  strict limit, and if the cache goes over the limit, an object in the cache could be evicted instantly, at
	///  a later point in time, or possibly never, all depending on the implementation details of the cache.
	public var totalCostLimit: Int {
		get { cache.totalCostLimit }
		set { cache.totalCostLimit = newValue }
	}

	/// The name of the cache. The default is "NetworkHandler: NetworkCache"
	public var name: String {
		get { cache.name }
		set { cache.name = newValue }
	}

	/// Access or modify the object associated with a specific `key` in the cache.
	///
	/// - Parameter key: The unique string representing the object to retrieve or store.
	/// - Returns: The `NetworkCacheItem` associated with the provided key, or `nil` if no item exists in
	/// either the memory cache or disk cache.
	///
	/// When accessing a key:
	/// - Attempts to retrieve the corresponding object from the in-memory cache first (faster).
	/// - If not found in memory, checks the disk-based backing store (slower),
	/// then decodes it into a `NetworkCacheItem`.
	///
	/// When storing a key:
	/// - Adds the item to both the memory cache and the disk cache. If the value
	/// is `nil`, the entry is removed from both caches.
	///
	/// Logs the cache hit/miss or storage activity for debugging purposes.
	public subscript(key: String) -> NetworkCacheItem? {
		get {
			if let cachedItem = cache.object(forKey: key as NSString) {
				logger.debug("Cache hit", metadata: ["Key": "\(key)"])
				return cachedItem
			} else if let codedData = diskCache.getData(for: key) {
				return try? Self.diskDecoder.decode(NetworkCacheItem.self, from: codedData)
			}
			return nil
		}
		set {
			if let newData = newValue {
				cache.setObject(newData, forKey: key as NSString, cost: newData.data.count)
				logger.debug("Stored cache data", metadata: ["Key": "\(key)"])
				diskCache.setData(try? Self.diskEncoder.encode(newData), key: key)
			} else {
				cache.removeObject(forKey: key as NSString)
				diskCache.deleteData(for: key)
			}
		}
	}

	public let logger: Logger

	// MARK: - Init
	/// Creates a new instance of `NetworkCache` with a given name, logger, and disk cache capacity.
	///
	/// - Parameters:
	///   - name: The name of the cache, used for organization and logging clarity.
	///   - logger: A `Logger` instance to report cache activity.
	///   - diskCacheCapacity: The maximum size of the disk cache in bytes. Defaults to `.max`, meaning unlimited.
	///
	/// This initializer sets up both an in-memory cache and a redundant disk
	/// cache, providing robust, persistent storage. A secondary logger is configured for the disk cache, based on
	/// the provided logger's settings.
	init(name: String, logger: Logger, diskCacheCapacity: UInt64 = .max) {
		self.logger = logger
		var diskLogger = Logger(label: "\(logger.label) - Disk Cache")
		diskLogger.logLevel = logger.logLevel
		diskLogger.handler = logger.handler
		self.diskCache = .init(capacity: diskCacheCapacity, cacheName: name, logger: diskLogger)
		self.name = name
	}

	// MARK: - Methods
	/// Clears the contents of the cache either in memory, on disk, or both.
	///
	/// - Parameters:
	///   - memory: A Boolean value indicating whether to clear the in-memory cache. Defaults to `true`.
	///   - disk: A Boolean value indicating whether to clear the disk cache. Defaults to `true`.
	///
	/// Use this method to completely wipe the cache, ensuring that no stale or outdated data remains.
	/// Logs these operations for visibility.
	public func reset(memory: Bool = true, disk: Bool = true) {
		if memory {
			cache.removeAllObjects()
			logger.debug("Cleared memory cache.", metadata: ["Name": "\(name)"])
		}
		if disk {
			diskCache.resetCache()
		}
	}

	/// Removes and optionally returns the cached object associated with the specified key.
	///
	/// - Parameter key: The unique string representing the object to remove from the cache.
	/// - Returns: The `NetworkCacheItem` that was associated with the key, or `nil` if no matching item was found.
	///
	/// This method removes the object from both the in-memory cache and the disk cache. It also logs the
	/// key removal for auditability. The return value allows you to retrieve the removed object if necessary.
	@discardableResult
	public func remove(objectFor key: String) -> NetworkCacheItem? {
		let cachedItem = cache.object(forKey: key as NSString)
		cache.removeObject(forKey: key as NSString)
		logger.debug("Deleted cached data", metadata: ["Key": "\(key)"])
		diskCache.deleteData(for: key)
		return cachedItem
	}
}

class NetworkCacheItem: Codable, @unchecked Sendable {
	let response: EngineResponseHeader
	let data: Data

	var cacheTuple: (Data, EngineResponseHeader) {
		(data, response)
	}

	enum CodingKeys: String, CodingKey {
		case response
		case data
	}

	init(response: EngineResponseHeader, data: Data) {
		self.response = response
		self.data = data
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let response = try container.decode(EngineResponseHeader.self, forKey: .response)
		self.response = response
		self.data = try container.decode(Data.self, forKey: .data)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(data, forKey: .data)
		try container.encode(response, forKey: .response)
	}

	enum CachedItemError: Error {
		case responseDataCorrupt
	}
}
