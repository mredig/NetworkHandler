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
			try self.init(
				for: request.urlRequest,
				awsKey: awsKey,
				awsSecret: awsSecret,
				awsRegion: awsRegion,
				awsService: awsService,
				hexContentHash: hexContentHash)
		}

	public func processRequest(_ request: NetworkRequest) throws -> NetworkRequest {
		let new = try processRequest(request.urlRequest)
		return request.updatingURLRequest { urlRequest in
			urlRequest = new
		}
	}
}
