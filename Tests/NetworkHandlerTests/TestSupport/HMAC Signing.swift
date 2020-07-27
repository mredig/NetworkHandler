
import Foundation
import CommonCrypto

enum HMACAlgorithm {
	case md5, sha1, sha224, sha256, sha384, sha512

	var hmacAlgValue: CCHmacAlgorithm {
		let value: Int
		switch self {
		case .md5:
			value = kCCHmacAlgMD5
		case .sha1:
			value = kCCHmacAlgSHA1
		case .sha224:
			value = kCCHmacAlgSHA224
		case .sha256:
			value = kCCHmacAlgSHA256
		case .sha384:
			value = kCCHmacAlgSHA384
		case .sha512:
			value = kCCHmacAlgSHA512
		}
		return CCHmacAlgorithm(value)
	}


	var digestLength: Int {
		let result: Int32
		switch self {
		case .md5:
			result = CC_MD5_DIGEST_LENGTH
		case .sha1:
			result = CC_SHA1_DIGEST_LENGTH
		case .sha224:
			result = CC_SHA224_DIGEST_LENGTH
		case .sha256:
			result = CC_SHA256_DIGEST_LENGTH
		case .sha384:
			result = CC_SHA384_DIGEST_LENGTH
		case .sha512:
			result = CC_SHA512_DIGEST_LENGTH
		}
		return Int(result)
	}
}

extension String {
	func hmac(algorithm: HMACAlgorithm, key: String) -> String {
		var result = [UInt8].init(repeating: 0, count: algorithm.digestLength)
		CCHmac(algorithm.hmacAlgValue, key, key.count, self, self.count, &result)

		let hmacData = Data(result)
		return hmacData.base64EncodedString(options: .lineLength76Characters)
	}
}
