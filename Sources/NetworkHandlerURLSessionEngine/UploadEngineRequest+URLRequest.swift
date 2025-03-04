import Foundation
import NetworkHandler

extension UploadEngineRequest {
	var urlRequest: URLRequest {
		var new = URLRequest(url: self.url)
		for header in self.headers {
			new.addValue(header.value.rawValue, forHTTPHeaderField: header.key.rawValue)
		}
		new.httpMethod = self.method.rawValue

		new.timeoutInterval = self.timeoutInterval

		return new
	}
}
