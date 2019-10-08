//
//  NetworkCache.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

/**
Essentially just a wrapper for NSCache, but specifically purposed for use with
NetworkHandler and does the work of converting `URL` <-> `NSURL` and `Data` <-> `NSData`
for you. Directly exposes some properties like `countLimit` and `totalCostLimit`
*/
public class NetworkCache {

	// MARK: - Properties
	private let cache = NSCache<NSURL, NSData>()

	/**
	The maximum number of objects the cache should hold.

	If 0, there is no count limit. The default value is 0.
	This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly, later, or possibly never, depending on the implementation details of the cache.
	*/
	public var countLimit: Int {
		get {
			return cache.countLimit
		}
		set {
			cache.countLimit = newValue
		}
	}

	/**
	The maximum total cost that the cache can hold before it starts evicting objects.

	If `0`, there is no total cost limit. The default value is `0`.
	When you add an object to the cache, you may pass in a specified cost for the object, such as the size in bytes of the object. If adding this object to the cache causes the cache’s total cost to rise above `totalCostLimit`, the cache may automatically evict objects until its total cost falls below `totalCostLimit`. The order in which the cache evicts objects is not guaranteed.
	This is not a strict limit, and if the cache goes over the limit, an object in the cache could be evicted instantly, at a later point in time, or possibly never, all depending on the implementation details of the cache.
	*/
	public var totalCostLimit: Int {
		get {
			return cache.totalCostLimit
		}
		set {
			cache.totalCostLimit = newValue
		}
	}

	/// The name of the cache. The default is "NetworkHandler: NetworkCache"
	public var name: String {
		get {
			return cache.name
		}
		set {
			cache.name = newValue
		}
	}

	public subscript(key: URL) -> Data? {
		get {
			return cache.object(forKey: key as NSURL) as Data?
		}
		set {
			if let newData = newValue {
				cache.setObject(newData as NSData, forKey: key as NSURL, cost: newData.count)
			} else {
				cache.removeObject(forKey: key as NSURL)
			}
		}
	}

	// MARK: - Init
	init() {
		name = "NetworkHandler: NetworkCache"
	}

	// MARK: - Methods
	public func reset() {
		cache.removeAllObjects()
	}

	@discardableResult public func remove(objectFor key: URL) -> Data? {
		let data = cache.object(forKey: key as NSURL) as Data?
		cache.removeObject(forKey: key as NSURL)
		return data
	}
}
