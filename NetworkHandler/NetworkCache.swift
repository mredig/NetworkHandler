//
//  NetworkCache.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

public class NetworkCache {
	private let cache = NSCache<NSURL, NSData>()

	public var countLimit: Int {
		get {
			return cache.countLimit
		}
		set {
			cache.countLimit = newValue
		}
	}

	public var totalCostLimit: Int {
		get {
			return cache.totalCostLimit
		}
		set {
			cache.totalCostLimit = newValue
		}
	}

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

	init() {
		cache.name = "NetworkHandler: NetworkCache"
	}

	public func reset() {
		cache.removeAllObjects()
	}

	@discardableResult public func remove(objectFor key: URL) -> Data? {
		let data = cache.object(forKey: key as NSURL) as Data?
		cache.removeObject(forKey: key as NSURL)
		return data
	}
}
