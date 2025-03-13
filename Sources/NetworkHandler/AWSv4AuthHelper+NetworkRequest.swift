import Foundation

extension AWSV4Signature {
	/// Initializes an `AWSV4Signature` instance for a `NetworkRequest`.
	///
	/// This initializer extracts the relevant metadata from a `NetworkRequest` to construct an AWS Signature V4 context.
	/// The `hexContentHash` argument must reflect the SHA-256 hash of the body payload specific to the signing process.
	///
	/// - Parameters:
	///   - request: A `NetworkRequest` object encapsulating details like method and URL.
	///   - date: The date and time for the request signature. Defaults to the current system date.
	///   - awsKey: The AWS access key string.
	///   - awsSecret: The AWS secret access key string.
	///   - awsRegion: The AWS region identifier for the request.
	///   - awsService: The AWS service name (e.g., `s3`).
	///   - hexContentHash: The precomputed SHA-256 hash of the request payload, as a hex string.
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

	/// Initializes an `AWSV4Signature` instance for an `UploadEngineRequest`.
	///
	/// - Parameters:
	///   - request: An `UploadEngineRequest` object representing an HTTP upload.
	///   - date: The date and time for the request signature. Defaults to the current system date.
	///   - awsKey: The AWS access key string.
	///   - awsSecret: The AWS secret access key string.
	///   - awsRegion: The AWS region identifier for the request.
	///   - awsService: The AWS service name (e.g., `s3`).
	///   - hexContentHash: The precomputed SHA-256 hash of the request payload, as a hex string.
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

	/// Initializes an `AWSV4Signature` instance for a `GeneralEngineRequest`.
	///
	/// - Parameters:
	///   - request: A `GeneralEngineRequest` object representing an HTTP download.
	///   - date: The date and time for the request signature. Defaults to the current system date.
	///   - awsKey: The AWS access key string.
	///   - awsSecret: The AWS secret access key string.
	///   - awsRegion: The AWS region identifier for the request.
	///   - awsService: The AWS service name (e.g., `s3`).
	///   - hexContentHash: The precomputed SHA-256 hash of the request payload, as a hex string.
	public init(
		for request: GeneralEngineRequest,
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

	/// Processes an existing `NetworkRequest` by attaching AWS-signed headers.
	///
	/// This function validates the `url` and `method` of the incoming request, generates AWS-specific headers,
	/// and merges them into the existing request's headers. The updated request is then returned.
	///
	/// - Parameter request: A `NetworkRequest` to be signed.
	/// - Returns: The updated `NetworkRequest` with the signed headers integrated.
	/// - Throws: `AWSAuthError` if the `url` or `method` on the request does not match
	///   those defined in the signature context.
	public func processRequest(_ request: NetworkRequest) throws -> NetworkRequest {
		try processRequestInfo(url: request.url, method: request.method) { newHeaders in
			var new = request
			new.headers += newHeaders
			return new
		}
	}

	/// Processes an `UploadEngineRequest` by attaching AWS-signed headers.
	///
	/// This function  validates the `url` and `method`, generates AWS-specific headers, and
	/// merges them into the request. A new `UploadEngineRequest` is returned post-processing.
	///
	/// - Parameter request: An `UploadEngineRequest` to be signed.
	/// - Returns: The updated `UploadEngineRequest` with the signed headers integrated.
	/// - Throws: `AWSAuthError` if the `url` or `method` on the request does not match
	///   those defined in the signature context.
	public func processRequest(_ request: UploadEngineRequest) throws -> UploadEngineRequest {
		let processed = try processRequest(.upload(request, payload: .data(Data())))
		guard case .upload(let request, _) = processed else {
			fatalError("Illegal request")
		}
		return request
	}

	/// Processes a `GeneralEngineRequest` by attaching AWS-signed headers.
	///
	/// This function  validates the `url` and `method`, generates AWS-specific headers, and merges
	/// them into the request. The final `GeneralEngineRequest` is returned post-processing.
	///
	/// - Parameter request: A `GeneralEngineRequest` to be signed.
	/// - Returns: The updated `GeneralEngineRequest` with the signed headers integrated.
	/// - Throws: `AWSAuthError` if the `url` or `method` on the request does not match
	///   those defined in the signature context.
	public func processRequest(_ request: GeneralEngineRequest) throws -> GeneralEngineRequest {
		let processed = try processRequest(.download(request))
		guard case .download(let request) = processed else {
			fatalError("Illegal request")
		}
		return request
	}
}
