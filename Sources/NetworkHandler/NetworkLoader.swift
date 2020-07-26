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
	func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTask
}

extension URLSession: NetworkLoader {
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTask {
		let task = self.dataTask(with: request) { data, response, error in
			completion(data, response, error)
		}
		return task
	}
}

public enum NetworkLoadingTaskStatus {
	case running, suspended, canceling, completed
}

public protocol NetworkLoadingTask {
	var status: NetworkLoadingTaskStatus { get }

	func resume()
	func cancel()
}

extension URLSessionDataTask: NetworkLoadingTask {
	public var status: NetworkLoadingTaskStatus {
		switch state {
		case .running:
			return .running
		case .canceling:
			return .canceling
		case .suspended:
			return .suspended
		case .completed:
			return .completed
		@unknown default:
			fatalError("Unknown network loading status! \(state)")
		}
	}

}
