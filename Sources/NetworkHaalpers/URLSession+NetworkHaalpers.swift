import Foundation

public extension URLSession {
	func dataTask(with request: NetworkRequest, completionHandler: ((Data?, URLResponse?, Error?) -> Void)? = nil) -> URLSessionDataTask {
		let task: URLSessionDataTask
		if let completionHandler = completionHandler {
			task = dataTask(with: request.urlRequest, completionHandler: completionHandler)
		} else {
			task = dataTask(with: request.urlRequest)
		}
		task.priority = request.priority.rawValue
		request.automaticStart ? task.resume() : Void()
		return task
	}

	func downloadTask(with request: NetworkRequest, completionHandler: ((URL?, URLResponse?, Error?) -> Void)? = nil) -> URLSessionDownloadTask {
		let task: URLSessionDownloadTask
		if let completionHandler = completionHandler {
			task = downloadTask(with: request.urlRequest, completionHandler: completionHandler)
		} else {
			task = downloadTask(with: request.urlRequest)
		}

		task.priority = request.priority.rawValue
		request.automaticStart ? task.resume() : Void()
		return task
	}

	func uploadTask(with request: NetworkRequest, from bodyData: Data, completionHandler: ((Data?, URLResponse?, Error?) -> Void)? = nil) -> URLSessionUploadTask {
		let task: URLSessionUploadTask
		if let completionHandler = completionHandler {
			task = uploadTask(with: request.urlRequest, from: bodyData, completionHandler: completionHandler)
		} else {
			task = uploadTask(with: request.urlRequest, from: bodyData)
		}

		task.priority = request.priority.rawValue
		request.automaticStart ? task.resume() : Void()
		return task
	}

	func uploadTask(with request: NetworkRequest, fromFile fileURL: URL, completionHandler: ((Data?, URLResponse?, Error?) -> Void)? = nil) -> URLSessionUploadTask {
		let task: URLSessionUploadTask
		if let completionHandler = completionHandler {
			task = uploadTask(with: request.urlRequest, fromFile: fileURL, completionHandler: completionHandler)
		} else {
			task = uploadTask(with: request.urlRequest, fromFile: fileURL)
		}

		task.priority = request.priority.rawValue
		request.automaticStart ? task.resume() : Void()
		return task
	}

	@available(iOS 13.0, *)
	func webSocketTask(with request: NetworkRequest) -> URLSessionWebSocketTask {
		let task = webSocketTask(with: request.urlRequest)

		task.priority = request.priority.rawValue
		request.automaticStart ? task.resume() : Void()
		return task
	}

	@available(iOS 15.0, *)
	func bytes(for request: NetworkRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (URLSession.AsyncBytes, URLResponse) {
		try await bytes(for: request.urlRequest, delegate: delegate)
	}

	@available(iOS 15.0, *)
	func data(for request: NetworkRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
		try await data(for: request.urlRequest, delegate: delegate)
	}

	@available(iOS 15.0, *)
	func download(for request: NetworkRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (URL, URLResponse) {
		try await download(for: request.urlRequest, delegate: delegate)
	}

	@available(iOS 15.0, *)
	func upload(for request: NetworkRequest, from bodyData: Data, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
		try await upload(for: request.urlRequest, from: bodyData, delegate: delegate)
	}

	@available(iOS 15.0, *)
	func upload(for request: NetworkRequest, fromFile fileURL: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
		try await upload(for: request.urlRequest, fromFile: fileURL, delegate: delegate)
	}

	#if canImport(Combine)
	@available(iOS 13.0, *)
	func dataTaskPublisher(for request: NetworkRequest) -> URLSession.DataTaskPublisher {
		dataTaskPublisher(for: request.urlRequest)
	}
	#endif
}
