//
//  NetworkLoader
//  NetworkHandler
//
//  Created by Michael Redig on 6/17/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

/// Provides an abstracted method to create a url network request to make testing easier.
public protocol NetworkLoader {
	func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask?
}

extension URLSession: NetworkLoader {
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask? {
		let task = self.dataTask(with: request) { data, response, error in
			completion(data, response, error)
		}
		return task
	}
}
