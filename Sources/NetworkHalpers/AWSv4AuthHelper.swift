import Foundation
import Crypto

public struct AWSV4Signature {
//	let authorization: String
//	let amzContentSha256: String
//	let host: String
//	let contentType: String
//	let amzDate: String

//	var allHeaders: []
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
		awsRegion: String,
		awsService: String,
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

			let scope = "\(Self.otherDateFormatterForSomeReason.string(from: date))/\(awsRegion)/\(awsService)/aws4_request"
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
			let dateRegionKey = HMAC<SHA256>.authenticationCode(for: Data(awsRegion.utf8), using: dateRegionKeySecret)

			let dateRegionServiceKeySecret = SymmetricKey(data: dateRegionKey)
			let dateRegionServiceKey = HMAC<SHA256>.authenticationCode(for: Data(awsService.utf8), using: dateRegionServiceKeySecret)

			let signingKeySecret = SymmetricKey(data: dateRegionServiceKey)
			let signingKey = HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: signingKeySecret)

			let signatureSecret = SymmetricKey(data: signingKey)
			let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: signatureSecret).hex()
		}
}
