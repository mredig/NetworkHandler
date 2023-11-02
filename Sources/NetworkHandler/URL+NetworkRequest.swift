import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public extension URL {
	/// Easy request generation.
	var request: NetworkRequest {
		NetworkRequest(urlRequest)
	}
}
