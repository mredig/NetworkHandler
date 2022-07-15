import Foundation
import Crypto

public struct AWSV4Signature {
	public let authorization: String
//	let amzContentSha256: String
//	let host: String
//	let contentType: String
//	let amzDate: String

//	var allHeaders: []
	public let amzHeaders: [HTTPHeaderKey: HTTPHeaderValue]
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

	public init(
		requestMethod: HTTPMethod,
		url: URL,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSRegion,
		awsService: AWSService,
		hexedContentHash: String,
		additionalSignedHeaders: [HTTPHeaderKey: HTTPHeaderValue]) {

			let components = URLComponents(url: url, resolvingAgainstBaseURL: false) ??
				URLComponents(string: url.absoluteString) ?? // will this make a difference?
				URLComponents() // don't crash and instead just make invalid data... maybe?

			let urlPath = components.path
//			let urlQueryItems = components.queryItems ?? []
//			let sortedQueryItems = urlQueryItems.sorted(by: { $0.name < $1.name })
//			let queryItemString = sortedQueryItems
//				.map {
//					"\($0.name)=\($0.value ?? "")"
//				}
//				.joined(separator: "&")

			let queryItemString = {
				let urlQueryItems = components.queryItems ?? []
				let sortedQueryItems = urlQueryItems.sorted(by: { $0.name < $1.name })
				var characterSet = CharacterSet.urlQueryAllowed
				characterSet.remove("/")
				return sortedQueryItems
					.map {
						"\($0.name)=\($0.value?.addingPercentEncoding(withAllowedCharacters: characterSet) ?? "")"
					}
					.joined(separator: "&")
			}()

			let (canonicalHeaders, signedHeaders) = {
				var allHeaders = additionalSignedHeaders.reduce(into: [String: String]()) {
					$0[$1.key.rawValue.lowercased()] = $1.value.rawValue
				}
				allHeaders["host"] = components.host
				allHeaders["x-amz-content-sha256"] = hexedContentHash

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
			}()

			let canonicalRequest = """
				\(requestMethod.rawValue)
				\(urlPath)
				\(queryItemString)
				\(canonicalHeaders)
				\(signedHeaders)
				\(hexedContentHash)
				"""

			let scope = "\(Self.otherDateFormatterForSomeReason.string(from: date))/\(awsRegion.rawValue)/\(awsService.rawValue)/aws4_request"
			let stringToSign = """
				AWS4-HMAC-SHA256
				\(Self.isoFormatter.string(from: date))
				\(scope)
				\(SHA256.hash(data: Data(canonicalRequest.utf8)).hex())
				"""

			let dateKeyInput = Self.otherDateFormatterForSomeReason.string(from: date)
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

			let authorizationString = "AWS4-HMAC-SHA256 Credential=\(awsKey)/\(scope),SignedHeaders=\(signedHeaders),Signature=\(signature)"

			self.authorization = authorizationString
			self.amzHeaders = [
				"x-amz-content-sha256": "\(hexedContentHash)",
				"x-amz-date": "\(Self.isoFormatter.string(from: date))",
				"Authorization": "\(authorizationString)"
			]
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
}
