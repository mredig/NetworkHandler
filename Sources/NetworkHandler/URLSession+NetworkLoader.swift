import Foundation

extension URLSession: NetworkLoader {
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTask {
		let urlSessionTask = self.dataTask(with: request) { data, response, error in
			completion(data, response, error)
		}
		return NetworkHandlerDataTask(urlSessionTask)
	}

	public func synchronousLoadData(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
		var data: Data?
		var response: URLResponse?
		var error: Error?

		let sem = DispatchSemaphore(value: 0)
		self.dataTask(with: request) { innerData, innerResponse, innerError in
			data = innerData
			response = innerResponse
			error = innerError
			sem.signal()
		}.resume()
		sem.wait()
		return (data, response, error)
	}
}
