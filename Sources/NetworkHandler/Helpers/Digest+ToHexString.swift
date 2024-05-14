import Foundation
import Crypto

extension Digest {
	func toHexString() -> String {
		map { byte in
			String(format: "%02hhx", byte)
		}
		.joined()
	}
}
