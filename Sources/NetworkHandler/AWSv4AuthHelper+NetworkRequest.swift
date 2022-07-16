import Foundation

extension AWSV4Signature {
	public init(
		for request: NetworkRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: String) throws {
			try self.init(
				for: request.urlRequest,
				awsKey: awsKey,
				awsSecret: awsSecret,
				awsRegion: awsRegion,
				awsService: awsService,
				hexContentHash: hexContentHash)
		}

	public func processRequest(_ request: NetworkRequest) throws -> NetworkRequest {
		guard
			url == request.url
		else { throw AWSAuthError.requestURLNoMatch }
		guard
			requestMethod == request.httpMethod
		else { throw AWSAuthError.requestMethodNoMatch }
		var request = request

		amzHeaders.forEach {
			request.setValue($0.value, forHTTPHeaderField: $0.key)
		}

		return request
	}
}
