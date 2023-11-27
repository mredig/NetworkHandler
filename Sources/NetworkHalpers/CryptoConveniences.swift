import Foundation
import Crypto

protocol DigestToValues: Sequence {
	func bytes() -> Data
	func hex() -> String
	func base64(options: Data.Base64EncodingOptions) -> String
}

extension DigestToValues where Element == UInt8 {
	func bytes() -> Data {
		Data(self)
	}

	func hex() -> String {
		self
			.map {
				let value = String($0, radix: 16)
				return value.count == 2 ? value : "0\(value)"
			}
			.joined()
	}

	func base64(options: Data.Base64EncodingOptions) -> String {
		bytes().base64EncodedString(options: options)
	}
}

extension SHA256Digest: DigestToValues {}
extension SHA384Digest: DigestToValues {}
extension SHA512Digest: DigestToValues {}
extension Insecure.MD5Digest: DigestToValues {}
extension Insecure.SHA1Digest: DigestToValues {}

extension HashedAuthenticationCode: DigestToValues {}
