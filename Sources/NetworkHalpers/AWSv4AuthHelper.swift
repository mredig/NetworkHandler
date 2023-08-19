import Foundation
import CryptoKit

public struct AWSV4Signature {

	public var requestMethod: HTTPMethod = .get
	public var url: URL
	public var date: Date
	public var awsKey: String
	public var awsSecret: String
	public var awsRegion: AWSRegion
	public var awsService: AWSService
	public var hexContentHash: AWSContentHash
	public var additionalSignedHeaders: [HTTPHeaderKey: HTTPHeaderValue]

	public init(
		requestMethod: HTTPMethod = .get,
		url: URL,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash,
		additionalSignedHeaders: [HTTPHeaderKey : HTTPHeaderValue]) {
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

	public init(
		for request: URLRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash) throws {
			guard
				let method = request.method
			else { throw AWSAuthError.noRequestMethod }
			guard
				let url = request.url
			else { throw AWSAuthError.noURL }

			self.init(
				requestMethod: method,
				url: url,
				date: date,
				awsKey: awsKey,
				awsSecret: awsSecret,
				awsRegion: awsRegion,
				awsService: awsService,
				hexContentHash: hexContentHash,
				additionalSignedHeaders: request.allHTTPHeaders)
		}

	@available(*, deprecated, message: "Use AWSContentHash.fromData(_:) with another initializer")
	public init(
		requestMethod: HTTPMethod,
		url: URL,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		payloadData: Data,
		additionalSignedHeaders: [HTTPHeaderKey : HTTPHeaderValue]) {
			self.init(
				requestMethod: requestMethod,
				url: url,
				date: date,
				awsKey: awsKey,
				awsSecret: awsSecret,
				awsRegion: awsRegion,
				awsService: awsService,
				hexContentHash: .fromData(payloadData),
				additionalSignedHeaders: additionalSignedHeaders)
		}

	public var amzHeaders: [HTTPHeaderKey: HTTPHeaderValue] {
		[
			"x-amz-content-sha256": "\(hexContentHash.rawValue)",
			"x-amz-date": "\(Self.isoDateString(from: date))",
			"Authorization": "\(authorizationString)"
		]
	}

	public func processRequest(_ request: URLRequest) throws -> URLRequest {
		guard
			url == request.url
		else { throw AWSAuthError.requestURLNoMatch }
		guard
			requestMethod == request.method
		else { throw AWSAuthError.requestMethodNoMatch }
		var request = request
		amzHeaders.forEach {
			request.setValue($0.value, forHTTPHeaderField: $0.key)
		}
		additionalSignedHeaders.forEach {
			request.setValue($0.value, forHTTPHeaderField: $0.key)
		}

		return request
	}

	public enum AWSAuthError: Error {
		case requestURLNoMatch
		case requestMethodNoMatch
		case noRequestMethod
		case noURL
	}
}

extension AWSV4Signature {
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

	public static func isoDateString(from date: Date) -> String {
		isoFormatter.string(from: date)
	}
	public static func otherDateString(from date: Date) -> String {
		otherDateFormatterForSomeReason.string(from: date)
	}

	private var components: URLComponents {
		URLComponents(url: url, resolvingAgainstBaseURL: false) ??
			URLComponents(string: url.absoluteString) ?? // will this make a difference?
			URLComponents() // don't crash and instead just make invalid data... maybe?
	}

	private var urlPath: String {
		components.path
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
		let dateRegionServiceKey = HMAC<SHA256>.authenticationCode(for: Data(awsService.rawValue.utf8), using: dateRegionServiceKeySecret)

		let signingKeySecret = SymmetricKey(data: dateRegionServiceKey)
		let signingKey = HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: signingKeySecret)

		let signatureSecret = SymmetricKey(data: signingKey)
		let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: signatureSecret).hex()
		return signature
	}

	public var authorizationString: String {
		let headerStuff = self.headerStuff
		return "AWS4-HMAC-SHA256 Credential=\(awsKey)/\(scope),SignedHeaders=\(headerStuff.signedHeaders),Signature=\(signature)"
	}

}


extension AWSV4Signature {
	public struct AWSRegion: RawRepresentable, ExpressibleByStringInterpolation {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		public static let usEast2: AWSRegion = "us-east-2"
		public static let usEast1: AWSRegion = "us-east-1"
		public static let usWest1: AWSRegion = "us-west-1"
		public static let usWest2: AWSRegion = "us-west-2"
		public static let afSouth1: AWSRegion = "af-south-1"
		public static let apEast1: AWSRegion = "ap-east-1"
		public static let apSoutheast3: AWSRegion = "ap-southeast-3"
		public static let apSouth1: AWSRegion = "ap-south-1"
		public static let apNortheast3: AWSRegion = "ap-northeast-3"
		public static let apNortheast2: AWSRegion = "ap-northeast-2"
		public static let apSoutheast1: AWSRegion = "ap-southeast-1"
		public static let apSoutheast2: AWSRegion = "ap-southeast-2"
		public static let apNortheast1: AWSRegion = "ap-northeast-1"
		public static let caCentral1: AWSRegion = "ca-central-1"
		public static let cnNorth1: AWSRegion = "cn-north-1"
		public static let cnNorthwest1: AWSRegion = "cn-northwest-1"
		public static let euCentral1: AWSRegion = "eu-central-1"
		public static let euWest1: AWSRegion = "eu-west-1"
		public static let euWest2: AWSRegion = "eu-west-2"
		public static let euSouth1: AWSRegion = "eu-south-1"
		public static let euWest3: AWSRegion = "eu-west-3"
		public static let euNorth1: AWSRegion = "eu-north-1"
		public static let meSouth1: AWSRegion = "me-south-1"
		public static let saEast1: AWSRegion = "sa-east-1"
	}

	public struct AWSService: RawRepresentable, ExpressibleByStringInterpolation {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		public static let s3: AWSService = "s3"
	}

	public struct AWSContentHash: RawRepresentable, ExpressibleByStringInterpolation {
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

		public static let emptyPayload: AWSContentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
		public static let unsignedPayload: AWSContentHash = "UNSIGNED-PAYLOAD"
	}
}
