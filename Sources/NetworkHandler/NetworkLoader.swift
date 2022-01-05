//
//  NetworkLoader
//  NetworkHandler
//
//  Created by Michael Redig on 6/17/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import NetworkHelpers
#if os(Linux)
import FoundationNetworking
#endif

/// Provides an abstracted method to create a url network request to make testing easier.
public protocol NetworkLoader {
	func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTask
	func synchronousLoadData(with request: URLRequest) -> (Data?, URLResponse?, Error?)
}

public enum NetworkLoadingTaskStatus {
	case running, suspended, canceling, completed
}

public typealias NetworkLoadingClosure = (NetworkLoadingTask) -> Void

/// Designed to be similar to `URLSessionDataTask`, (intentionally allowing for `NetworkHandlerDataTask` to wrap a `URLSessionDataTask`), but also
/// provide a layer of conveneince provided by NetworkHandler
public protocol NetworkLoadingTask: AnyObject {
	var status: NetworkLoadingTaskStatus { get }

	var result: Result<Data?, Error>? { get }

	var progress: Progress { get }

	var priority: NetworkRequest.Priority { get set }

	func resume()
	func cancel()
	func suspend()

	func eraseToAnyHashable() -> AnyHashable

	@discardableResult func onStatusUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self
	@discardableResult func onProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self
	@discardableResult func onCompletion(_ perform: @escaping NetworkLoadingClosure) -> Self
}

protocol NetworkLoadingTaskEditor: NetworkLoadingTask {
	func setResult(_ result: Result<Data?, Error>)
}

#if canImport(Combine)
import Combine

@available(iOS 13.0, tvOS 13.0, macOS 15.0, watchOS 6.0, *)
public extension NetworkLoadingTask {
	var statusPublisher: PassthroughSubject<NetworkLoadingTaskStatus, Never> {
		let publisher = PassthroughSubject<NetworkLoadingTaskStatus, Never>()
		onStatusUpdated { task in
			publisher.send(task.status)
		}
		return publisher
	}

	var progressPublisher: PassthroughSubject<Progress, Never> {
		let publisher = PassthroughSubject<Progress, Never>()
		onProgressUpdated { task in
			publisher.send(task.progress)
		}
		return publisher
	}

	var completionPublisher: PassthroughSubject<Result<Data?, Error>?, Never> {
		let publisher = PassthroughSubject<Result<Data?, Error>?, Never>()
		onCompletion { task in
			publisher.send(task.result)
		}
		return publisher
	}
}
#endif
