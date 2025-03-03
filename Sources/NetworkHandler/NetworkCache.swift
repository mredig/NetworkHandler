import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


/**
Idea to resolve non blocking issue in [this test](test://com.apple.xcode/NetworkHandler/NetworkHandlerTests/NetworkCacheTests/testCacheAddRemove)

 create a cache-cache. Create a dict that stores the value right away, (using a lock for thread safety). then periodically check if the backing cache value is populated.
 once it's populated, clear from the cache-cache. in the meantime, the cache-cache can serve up the content
 */


/**
Essentially just a wrapper for NSCache, but adds redundancy in a disk cache. Specifically purposed for 
use with NetworkHandler
*/
class NetworkCache {
	// MARK: - Properties
	private let cache = NSCache<NSString, NetworkCacheItem>()
	let diskCache: NetworkDiskCache
	private static let diskEncoder = PropertyListEncoder()
	private static let diskDecoder = PropertyListDecoder()

	/**
	The maximum number of objects the cache should hold.

	If 0, there is no count limit. The default value is 0.
	This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly, 
	later, or possibly never, depending on the implementation details of the cache.
	*/
	public var countLimit: Int {
		get { cache.countLimit }
		set { cache.countLimit = newValue }
	}

	/**
	The maximum total cost that the cache can hold before it starts evicting objects.

	If `0`, there is no total cost limit. The default value is `0`.
	When you add an object to the cache, you may pass in a specified cost for the object, such as the size in bytes of 
	the object. If adding this object to the cache causes the cache’s total cost to rise above `totalCostLimit`, the 
	cache may automatically evict objects until its total cost falls below `totalCostLimit`. The order in which the cache
	evicts objects is not guaranteed. This is not a strict limit, and if the cache goes over the limit, an object in the
	cache could be evicted instantly, at a later point in time, or possibly never, all depending on the implementation
	details of the cache.
	*/
	public var totalCostLimit: Int {
		get { cache.totalCostLimit }
		set { cache.totalCostLimit = newValue }
	}

	/// The name of the cache. The default is "NetworkHandler: NetworkCache"
	public var name: String {
		get { cache.name }
		set { cache.name = newValue }
	}

	public subscript(key: String) -> NetworkCacheItem? {
		get {
			if let cachedItem = cache.object(forKey: key as NSString) {
				return cachedItem
			} else if let codedData = diskCache.getData(for: key) {
				return try? Self.diskDecoder.decode(NetworkCacheItem.self, from: codedData)
			}
			return nil
		}
		set {
			if let newData = newValue {
				cache.setObject(newData, forKey: key as NSString, cost: newData.data.count)
				diskCache.setData(try? Self.diskEncoder.encode(newData), key: key)
			} else {
				cache.removeObject(forKey: key as NSString)
				diskCache.deleteData(for: key)
			}
		}
	}

	// MARK: - Init
	init(name: String, diskCacheCapacity: UInt64 = .max) {
		self.diskCache = .init(capacity: diskCacheCapacity, cacheName: name)
		self.name = name
	}

	// MARK: - Methods
	public func reset(memory: Bool = true, disk: Bool = true) {
		if memory {
			cache.removeAllObjects()
		}
		if disk {
			diskCache.resetCache()
		}
	}

	@discardableResult public func remove(objectFor key: String) -> NetworkCacheItem? {
		let cachedItem = cache.object(forKey: key as NSString)
		cache.removeObject(forKey: key as NSString)
		diskCache.deleteData(for: key)
		return cachedItem
	}
}

class NetworkCacheItem: Codable {
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
