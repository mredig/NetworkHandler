import Foundation
#if os(Linux)
import FoundationNetworking
#endif


public extension URL {
	/// Easy request generation.
	var urlRequest: URLRequest {
		URLRequest(url: self)
	}
}
