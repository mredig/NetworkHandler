import Foundation
import Crypto
import SwiftPizzaSnips

/// Represents the AWS Signature Version 4 signing process, which is used to securely sign AWS API requests.
/// This structure stores all necessary information for constructing the AWS signature including HTTP method,
/// request details, AWS credentials, and additional options.
///
/// Use `AWSV4Signature` to generate header values required for authentication against AWS APIs.
public struct AWSV4Signature: Hashable, Sendable, Withable {
	/// The HTTP method (e.g., GET, POST) used for the request.
	/// Defaults to `.get`.
	public var requestMethod: HTTPMethod = .get
	/// The URL of the API request to be signed.
	/// It is a critical component in building the canonical request string.
	public var url: URL
	/// The date and time associated with the request.
	/// Defaults to the current system date during initialization of the structure.
	/// Used as part of the signature generation process to ensure secure and time-sensitive requests.
	public var date: Date
	/// The AWS Access Key ID. This uniquely identifies the user's AWS credentials and is used in the signature process.
	public var awsKey: String
	/// The AWS Secret Access Key. This is used to calculate the HMAC signature as part of the authentication process.
	/// It must never be exposed to anyone, especially not in logs or UI.
	public var awsSecret: String
	/// The AWS region to which the request is being made (e.g., `us-east-1`).
	/// The value is typically a string identifier defined by AWS.
	public var awsRegion: AWSRegion
	/// The AWS service being accessed (e.g., `s3`).
	/// The value aligns with service names defined by AWS and is an input for generating a request scope.
	public var awsService: AWSService
	/// A SHA-256 hash of the HTTP request's body content, expressed as a hex string.
	///
	/// For unsigned payloads or GET requests (which generally have no body),
	/// specific placeholder values such as `AWSContentHash.emptyPayload` or
	/// `AWSContentHash.unsignedPayload` can be used.
	public var hexContentHash: AWSContentHash
	/// Custom HTTP headers that you want to include in the signature calculation.
	/// Make sure to omit these headers from the request yourself as they are added during the `processRequest()` call.
	public var additionalSignedHeaders: [HTTPHeaders.Header.Key: HTTPHeaders.Header.Value]
	
	/// Initializes a new instance of `AWSV4Signature` with the provided request attributes.
	///
	/// - Parameters:
	///   - requestMethod: The HTTP method of the request. Defaults to `.get`.
	///   - url: The full URL for the API request.
	///   - date: The date and time for the request signature. Defaults to the current date.
	///   - awsKey: The AWS access key.
	///   - awsSecret: The AWS secret access key.
	///   - awsRegion: The AWS region identifier for the API endpoint.
	///   - awsService: The AWS service name for the request (e.g., `s3`).
	///   - hexContentHash: The SHA-256 hash of the request body, precomputed as a hex string.
	///   - additionalSignedHeaders: Any additional headers to include in the signing process.
	///   Make sure to omit these headers from the request yourself as they are added during the `processRequest()` call.
	public init(
		requestMethod: HTTPMethod = .get,
		url: URL,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash,
		additionalSignedHeaders: [HTTPHeaders.Header.Key: HTTPHeaders.Header.Value]) {
			self.requestMethod = requestMethod
			self.url = url
			self.date = date
			self.awsKey = awsKey
			self.awsSecret = awsSecret
			self.awsRegion = awsRegion
			self.awsService = awsService
			self.hexContentHash = hexContentHash
			self.additionalSignedHeaders = additionalSignedHeaders
		}
	
	/// Constructs the necessary AWS-specific HTTP headers (`x-amz-*`) to be added to the signed request.
	///
	/// Includes:
	/// - `x-amz-content-sha256`: The SHA-256 content hash of the request body.
	/// - `x-amz-date`: The ISO8601-formatted timestamp for the request date.
	/// - `Authorization`: The computed AWS Authorization header.
	///
	/// Returns a dictionary of header keys and values for use in the signed request.
	public var amzHeaders: [HTTPHeaders.Header.Key: HTTPHeaders.Header.Value] {
		[
			"x-amz-content-sha256": "\(hexContentHash.rawValue)",
			"x-amz-date": "\(Self.isoDateString(from: date))",
			"Authorization": "\(authorizationString)",
		]
	}
	
	/// Facilitates handling of AWS-signed requests by providing headers to a closure and collecting the result.
	///
	/// This method verifies the `url` and `method` of the request match the instance's defined values,
	/// ensuring consistency during signature generation. It then builds a complete set of headers
	/// (`amzHeaders` combined with `additionalSignedHeaders`) and passes them to the given closure.
	///
	/// The user is expected to process and integrate these headers into their own HTTP request type
	/// in the closure, which is then returned by the method.
	///
	/// - Parameters:
	///   - url: The URL for the request (compared against the signature's `url`).
	///   - method: The HTTP method for the request (compared against `requestMethod`).
	///   - headersBlock: A closure that receives the computed headers (`HTTPHeaders`) and outputs the final processed value.
	///
	/// - Returns: The output of the `headersBlock` closure, expected to represent the finalized request header set.
	///
	/// - Throws: `AWSAuthError` if the provided `url` or `method` does not match the expected values.
	public func processRequestInfo<T>(
		url: URL,
		method: HTTPMethod,
		headersBlock: (HTTPHeaders) -> T
	) throws(AWSAuthError) -> T {
		guard url == self.url else {
			throw .requestURLNoMatch
		}
		guard method == self.requestMethod else {
			throw .requestMethodNoMatch
		}

		let headers: HTTPHeaders = {
			var start: HTTPHeaders = []
			amzHeaders.forEach {
				let newHeader = HTTPHeaders.Header(key: $0.key, value: $0.value)
				start.append(newHeader)
			}
			additionalSignedHeaders.forEach {
				let newHeader = HTTPHeaders.Header(key: $0.key, value: $0.value)
				start.append(newHeader)
			}
			return start
		}()

		return headersBlock(headers)
	}

	public enum AWSAuthError: Error {
		case requestURLNoMatch
		case requestMethodNoMatch
		case noRequestMethod
		case noURL
	}
}

extension AWSV4Signature {
	nonisolated(unsafe)
	private static let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.formatOptions = [.withColonSeparatorInTime, .withDashSeparatorInDate, .withInternetDateTime]
		return formatter
	}()
	private static let otherDateFormatterForSomeReason: DateFormatter = {
		let formatter = DateFormatter()
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.dateFormat = "yyyyMMdd"
		return formatter
	}()
	
	/// Converts a `Date` to a properly iso formatted date string, suitable for AWSv4 auth.
	public static func isoDateString(from date: Date) -> String {
		isoFormatter.string(from: date)
	}

	/// Converts a `Date` to a formatted date string, suitable for a weird part of AWSv4 auth.
	public static func otherDateString(from date: Date) -> String {
		otherDateFormatterForSomeReason.string(from: date)
	}

	private var components: URLComponents {
		URLComponents(url: url, resolvingAgainstBaseURL: false) ??
			URLComponents(string: url.absoluteString) ?? // will this make a difference?
			URLComponents() // don't crash and instead just make invalid data... maybe?
	}

	static private let allowedCharacters: CharacterSet = {
		// UriEncode() rules at https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
		// 'A'-'Z', 'a'-'z', '0'-'9', '-', '.', '_', and '~' (plus '/' can be used for a separator)
		var set = CharacterSet()
		set.insert(charactersIn: "A".unicodeScalars.first!..."Z".unicodeScalars.first!)
		set.insert(charactersIn: "a".unicodeScalars.first!..."z".unicodeScalars.first!)
		set.insert(charactersIn: "a"..."z")
		set.insert(charactersIn: "0".unicodeScalars.first!..."9".unicodeScalars.first!)
		set.insert("-")
		set.insert(".")
		set.insert("_")
		set.insert("~")
		set.insert("/")
		return set
	}()
	private var urlPath: String {
		let path = components.path.addingPercentEncoding(withAllowedCharacters: Self.allowedCharacters) ?? components.path
		guard path.isEmpty == false else {
			return "/"
		}
		return path
	}

	private var queryItemString: String {
		let urlQueryItems = components.queryItems ?? []
		let sortedQueryItems = urlQueryItems.sorted(by: { $0.name < $1.name })
		var characterSet = CharacterSet.urlQueryAllowed
		characterSet.remove("/")
		return sortedQueryItems
			.map {
				"\($0.name)=\($0.value?.addingPercentEncoding(withAllowedCharacters: characterSet) ?? "")"
			}
			.joined(separator: "&")
	}

	private var headerStuff: (canonicalHeaders: String, signedHeaders: String) {
		var allHeaders = additionalSignedHeaders.reduce(into: [String: String]()) {
			$0[$1.key.rawValue.lowercased()] = $1.value.rawValue
		}
		allHeaders["host"] = components.host
		allHeaders["x-amz-content-sha256"] = hexContentHash.rawValue

		let sortedHeaders = allHeaders.sorted(by: { $0.key < $1.key })
		let signedHeaders = sortedHeaders
			.map(\.key)
			.joined(separator: ";")
		let canonicalHeaders = sortedHeaders
			.map {
				"\($0.key):\($0.value.trimmingCharacters(in: .whitespacesAndNewlines))"
			}
			.joined(separator: "\n")

		return (canonicalHeaders + "\n", signedHeaders)
	}

	var canonicalRequest: String {
		let headerStuff = self.headerStuff
		return """
		\(requestMethod.rawValue)
		\(urlPath)
		\(queryItemString)
		\(headerStuff.canonicalHeaders)
		\(headerStuff.signedHeaders)
		\(hexContentHash.rawValue)
		"""
	}

	var scope: String {
		"\(Self.otherDateString(from: date))/\(awsRegion.rawValue)/\(awsService.rawValue)/aws4_request"
	}

	var stringToSign: String {
		"""
		AWS4-HMAC-SHA256
		\(Self.isoDateString(from: date))
		\(scope)
		\(SHA256.hash(data: Data(canonicalRequest.utf8)).hex())
		"""
	}

	var signature: String {
		let dateKeyInput = Self.otherDateString(from: date)
		let dateKeySecret = "AWS4\(awsSecret)"
		let dateKeySecret2 = SymmetricKey(data: Data(dateKeySecret.utf8))
		let dateKey = HMAC<SHA256>.authenticationCode(for: Data(dateKeyInput.utf8), using: dateKeySecret2)

		let dateRegionKeySecret = SymmetricKey(data: dateKey)
		let dateRegionKey = HMAC<SHA256>.authenticationCode(for: Data(awsRegion.rawValue.utf8), using: dateRegionKeySecret)

		let dateRegionServiceKeySecret = SymmetricKey(data: dateRegionKey)
		let dateRegionServiceKey = HMAC<SHA256>
			.authenticationCode(
				for: Data(awsService.rawValue.utf8),
				using: dateRegionServiceKeySecret)

		let signingKeySecret = SymmetricKey(data: dateRegionServiceKey)
		let signingKey = HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: signingKeySecret)

		let signatureSecret = SymmetricKey(data: signingKey)
		let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: signatureSecret).hex()
		return signature
	}
	
	/// The completed AWS Authorization header string, as constructed during the signing process.
	///
	/// This string includes:
	/// - Your AWS access key.
	/// - The timestamp identifying the scope.
	/// - SignedHeaders defining the included headers.
	/// - The final signature.
	///
	/// Typically, this value is automatically incorporated into authenticated requests
	/// using `processRequestInfo`. However, it is exposed for advanced use if manual request construction is required.
	public var authorizationString: String {
		let headerStuff = self.headerStuff
		return """
			AWS4-HMAC-SHA256 Credential=\(awsKey)/\(scope),\
			SignedHeaders=\(headerStuff.signedHeaders),Signature=\(signature)
			"""
	}
}

extension AWSV4Signature {
	/// Represents an AWS Region (e.g., `us-east-1`, `eu-west-2`), which is
	/// required for scoping the request signature.
	///
	/// This is a type-safe wrapper around a raw string.
	public struct AWSRegion: RawRepresentable, Hashable, Withable, Sendable, ExpressibleByStringInterpolation {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}
		
		/// Convenience for the `us-east-2` AWS region
		public static let usEast2: AWSRegion = "us-east-2"
		/// Convenience for the `us-east-1` AWS region
		public static let usEast1: AWSRegion = "us-east-1"
		/// Convenience for the `us-west-1` AWS region
		public static let usWest1: AWSRegion = "us-west-1"
		/// Convenience for the `us-west-2` AWS region
		public static let usWest2: AWSRegion = "us-west-2"
		/// Convenience for the `af-south-1` AWS region
		public static let afSouth1: AWSRegion = "af-south-1"
		/// Convenience for the `ap-east-1` AWS region
		public static let apEast1: AWSRegion = "ap-east-1"
		/// Convenience for the `ap-southeast-3` AWS region
		public static let apSoutheast3: AWSRegion = "ap-southeast-3"
		/// Convenience for the `ap-south-1` AWS region
		public static let apSouth1: AWSRegion = "ap-south-1"
		/// Convenience for the `ap-northeast-3` AWS region
		public static let apNortheast3: AWSRegion = "ap-northeast-3"
		/// Convenience for the `ap-northeast-2` AWS region
		public static let apNortheast2: AWSRegion = "ap-northeast-2"
		/// Convenience for the `ap-southeast-1` AWS region
		public static let apSoutheast1: AWSRegion = "ap-southeast-1"
		/// Convenience for the `ap-southeast-2` AWS region
		public static let apSoutheast2: AWSRegion = "ap-southeast-2"
		/// Convenience for the `ap-northeast-1` AWS region
		public static let apNortheast1: AWSRegion = "ap-northeast-1"
		/// Convenience for the `ca-central-1` AWS region
		public static let caCentral1: AWSRegion = "ca-central-1"
		/// Convenience for the `cn-north-1` AWS region
		public static let cnNorth1: AWSRegion = "cn-north-1"
		/// Convenience for the `cn-northwest-1` AWS region
		public static let cnNorthwest1: AWSRegion = "cn-northwest-1"
		/// Convenience for the `eu-central-1` AWS region
		public static let euCentral1: AWSRegion = "eu-central-1"
		/// Convenience for the `eu-west-1` AWS region
		public static let euWest1: AWSRegion = "eu-west-1"
		/// Convenience for the `eu-west-2` AWS region
		public static let euWest2: AWSRegion = "eu-west-2"
		/// Convenience for the `eu-south-1` AWS region
		public static let euSouth1: AWSRegion = "eu-south-1"
		/// Convenience for the `eu-west-3` AWS region
		public static let euWest3: AWSRegion = "eu-west-3"
		/// Convenience for the `eu-north-1` AWS region
		public static let euNorth1: AWSRegion = "eu-north-1"
		/// Convenience for the `me-south-1` AWS region
		public static let meSouth1: AWSRegion = "me-south-1"
		/// Convenience for the `sa-east-1` AWS region
		public static let saEast1: AWSRegion = "sa-east-1"
	}
	
	/// Represents an AWS Service name (e.g., `s3`, `dynamodb`), required for constructing the request scope.
	///
	/// This is a type-safe wrapper around a raw string. A static convenience value is provided for `s3`.
	public struct AWSService: RawRepresentable, Hashable, Withable, Sendable, ExpressibleByStringInterpolation {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}
		
		/// Convenience for the `s3` AWS service
		public static let s3: AWSService = "s3"
	}
	
	/// Represents the SHA-256 hash of the HTTP body in hexadecimal format.
	/// Used as part of the canonical request for AWS Signature Version 4.
	///
	/// This is a type-safe wrapper around a raw string. Convenience values are provided for unsigned
	/// and empty payloads.
	///
	/// - `emptyPayload`: Use when the payload is empty.
	/// - `unsignedPayload`: Use when the payload is unsigned.
	public struct AWSContentHash: RawRepresentable, Hashable, Withable, Sendable, ExpressibleByStringInterpolation {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		public static func fromData(_ payloadData: Data) -> AWSContentHash {
			let hash = SHA256.hash(data: payloadData)
			return .fromShaHashDigest(hash)
		}

		public static func fromShaHashDigest(_ hash: SHA256Digest) -> AWSContentHash {
			AWSContentHash(rawValue: "\(hash.hex())")
		}
		
		/// Convenience for when a payload is empty.
		public static let emptyPayload: AWSContentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
		/// Convenience for when a payload is unsigned.
		public static let unsignedPayload: AWSContentHash = "UNSIGNED-PAYLOAD"
	}
}
