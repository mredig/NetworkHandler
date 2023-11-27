import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

enum URLResponseCoder {
	private static let key = "life.knowme.urlresponse"

	static func encode(response: HTTPURLResponse) -> Data {
		let keyedCoder = NSKeyedArchiver(requiringSecureCoding: true)
		keyedCoder.encode(response, forKey: Self.key)
		keyedCoder.finishEncoding()
		return keyedCoder.encodedData
	}

	static func decodeResponse(from data: Data) -> HTTPURLResponse? {
		let uncoder = try? NSKeyedUnarchiver(forReadingFrom: data)
		return uncoder?.decodeObject(of: HTTPURLResponse.self, forKey: Self.key)
	}
}

class NetworkCacheItem: Codable {
	let response: HTTPURLResponse
	let data: Data

	var cacheTuple: (Data, HTTPURLResponse) {
		(data, response)
	}

	enum CodingKeys: String, CodingKey {
		case response
		case data
	}

	init(response: HTTPURLResponse, data: Data) {
		self.response = response
		self.data = data
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let responseData = try container.decode(Data.self, forKey: .response)
		guard
			let response = URLResponseCoder.decodeResponse(from: responseData)
		else { throw CachedItemError.responseDataCorrupt }
		self.response = response
		self.data = try container.decode(Data.self, forKey: .data)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(data, forKey: .data)
		try container.encode(URLResponseCoder.encode(response: response), forKey: .response)
	}

	enum CachedItemError: Error {
		case responseDataCorrupt
	}
}
