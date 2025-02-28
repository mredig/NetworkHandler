import Foundation

extension DownloadEngineRequest {
	var urlRequest: URLRequest {
		var new = URLRequest(url: self.url)
		for header in self.headers {
			new.addValue(header.value, forHTTPHeaderField: header.key)
		}
		new.httpMethod = self.method.rawValue

		new.httpBody = payload
		new.timeoutInterval = self.timeoutInterval

		return new
	}
}
