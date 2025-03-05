import Foundation

extension AWSV4Signature {
	public init(
		for request: NetworkRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash
	) {
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

	public init(
		for request: UploadEngineRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash
	) {
		self.init(
			for: .upload(request, payload: .data(Data())),
			date: date,
			awsKey: awsKey,
			awsSecret: awsSecret,
			awsRegion: awsRegion,
			awsService: awsService,
			hexContentHash: hexContentHash)
	}

	public init(
		for request: DownloadEngineRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash
	) {
		self.init(
			for: .download(request),
			date: date,
			awsKey: awsKey,
			awsSecret: awsSecret,
			awsRegion: awsRegion,
			awsService: awsService,
			hexContentHash: hexContentHash)
	}

	public func processRequest(_ request: NetworkRequest) throws -> NetworkRequest {
		try processRequestInfo(url: request.url, method: request.method) { newHeaders in
			var new = request
			new.headers += newHeaders
			return new
		}
	}

	public func processRequest(_ request: UploadEngineRequest) throws -> UploadEngineRequest {
		let processed = try processRequest(.upload(request, payload: .data(Data())))
		guard case .upload(let request, _) = processed else {
			fatalError("Illegal request")
		}
		return request
	}

	public func processRequest(_ request: DownloadEngineRequest) throws -> DownloadEngineRequest {
		let processed = try processRequest(.download(request))
		guard case .download(let request) = processed else {
			fatalError("Illegal request")
		}
		return request
	}
}
