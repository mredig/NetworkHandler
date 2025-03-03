import Foundation

extension AWSV4Signature {
	public init(
		for request: NetworkRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash) throws {
			self.init(
				requestMethod: request.method,
				url: request.url,
				date: date,
				awsKey: awsKey,
				awsSecret: awsSecret,
				awsRegion: awsRegion,
				awsService: awsService,
				hexContentHash: hexContentHash,
				additionalSignedHeaders: [:])
		}

	public func processRequest(_ request: NetworkRequest) throws -> NetworkRequest {
		try processRequestInfo(url: request.url, method: request.method) { newHeaders in
			var new = request
			new.headers += newHeaders
			return new
		}
	}
}
