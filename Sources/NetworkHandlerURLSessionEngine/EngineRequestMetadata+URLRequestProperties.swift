import NetworkHandler
import Foundation

public extension EngineRequestMetadata {
	internal var derivedURLRequest: URLRequest {
		get {
			if let existing: URLRequest = extensionStorageRetrieve(valueForKey: #function) {
				existing
			} else {
				URLRequest(url: url)
			}
		}
		set {
			extensionStorage(store: newValue, with: #function)
		}
	}

	var cachePolicy: URLRequest.CachePolicy {
		get { derivedURLRequest.cachePolicy }
		set { derivedURLRequest.cachePolicy = newValue }
	}

	var mainDocumentURL: URL? {
		get { derivedURLRequest.mainDocumentURL }
		set { derivedURLRequest.mainDocumentURL = newValue }
	}

	var httpShouldHandleCookies: Bool {
		get { derivedURLRequest.httpShouldHandleCookies }
		set { derivedURLRequest.httpShouldHandleCookies = newValue }
	}

	var httpShouldUsePipelining: Bool {
		get { derivedURLRequest.httpShouldUsePipelining }
		set { derivedURLRequest.httpShouldUsePipelining = newValue }
	}

	var allowsCellularAccess: Bool {
		get { derivedURLRequest.allowsCellularAccess }
		set { derivedURLRequest.allowsCellularAccess = newValue }
	}

	var allowsConstrainedNetworkAccess: Bool {
		get { derivedURLRequest.allowsConstrainedNetworkAccess }
		set { derivedURLRequest.allowsConstrainedNetworkAccess = newValue }
	}

	var allowsExpensiveNetworkAccess: Bool {
		get { derivedURLRequest.allowsExpensiveNetworkAccess }
		set { derivedURLRequest.allowsExpensiveNetworkAccess = newValue }
	}

	var networkServiceType: URLRequest.NetworkServiceType {
		get { derivedURLRequest.networkServiceType }
		set { derivedURLRequest.networkServiceType = newValue }
	}

	var attribution: URLRequest.Attribution {
		get { derivedURLRequest.attribution }
		set { derivedURLRequest.attribution = newValue }
	}

	@available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 1.0, watchOS 9.1, *)
	var allowsPersistentDNS: Bool {
		get { derivedURLRequest.allowsPersistentDNS }
		set { derivedURLRequest.allowsPersistentDNS = newValue }
	}

	var assumesHTTP3Capable: Bool {
		get { derivedURLRequest.assumesHTTP3Capable }
		set { derivedURLRequest.assumesHTTP3Capable = newValue }
	}

	var requiresDNSSECValidation: Bool {
		get { derivedURLRequest.requiresDNSSECValidation }
		set { derivedURLRequest.requiresDNSSECValidation = newValue }
	}
}
