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
	func synchronousLoadData(with request: URLRequest) -> (Data?, URLResponse?, Error?)
}

public enum NetworkLoadingTaskStatus {
	case running, suspended, canceling, completed
}

public typealias NetworkLoadingClosure = (NetworkLoadingTask) -> Void
public protocol NetworkLoadingTask: AnyObject {
	var status: NetworkLoadingTaskStatus { get }

	var result: Result<Data?, Error>? { get }

	var countOfBytesExpectedToReceive: Int64 { get }
	var countOfBytesReceived: Int64 { get }
	var countOfBytesExpectedToSend: Int64 { get }
	var countOfBytesSent: Int64 { get }

	var priority: Float { get set }

	func resume()
	func cancel()
	func suspend()

	@discardableResult func onUploadProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self
	@discardableResult func onDownloadProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self
	@discardableResult func onCompletion(_ perform: @escaping NetworkLoadingClosure) -> Self
}

protocol NetworkLoadingTaskEditor: NetworkLoadingTask {
	func setResult(_ result: Result<Data?, Error>)
}
