import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URL {
	/// Easy request generation.
	var request: NetworkRequest {
		NetworkRequest(urlRequest)
	}
}
