import Foundation

extension UploadEngineRequest {
	var urlRequest: URLRequest {
		var new = URLRequest(url: self.url)
		for header in self.headers {
			new.addValue(header.value, forHTTPHeaderField: header.key)
		}
		new.httpMethod = self.method.rawValue

		switch payload {
		case .data(let data):
			new.httpBodyStream = InputStream(data: data)
		case .localFile(let localFile):
			new.httpBodyStream = InputStream(url: localFile)
		case .streamProvider(let stream):
			new.httpBodyStream = stream
		}

		new.timeoutInterval = self.timeoutInterval

		return new
	}
}
