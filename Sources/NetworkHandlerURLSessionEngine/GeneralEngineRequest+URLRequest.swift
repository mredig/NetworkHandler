import Foundation
import NetworkHandler

extension GeneralEngineRequest {
	package var urlRequest: URLRequest {
		var new = URLRequest(url: self.url)
		for header in self.headers {
			new.addValue(header.value.rawValue, forHTTPHeaderField: header.key.rawValue)
		}
		new.httpMethod = self.method.rawValue

		new.httpBody = payload
		new.timeoutInterval = self.timeoutInterval

		let storedRequest = self.derivedURLRequest

		new.cachePolicy = storedRequest.cachePolicy
		new.mainDocumentURL = storedRequest.mainDocumentURL
		new.httpShouldHandleCookies = storedRequest.httpShouldHandleCookies
		new.httpShouldUsePipelining = storedRequest.httpShouldUsePipelining
		new.allowsCellularAccess = storedRequest.allowsCellularAccess
		new.allowsConstrainedNetworkAccess = storedRequest.allowsConstrainedNetworkAccess
		new.allowsExpensiveNetworkAccess = storedRequest.allowsExpensiveNetworkAccess
		new.networkServiceType = storedRequest.networkServiceType
		new.attribution = storedRequest.attribution
		if #available(macOS 15.0, iOS 18.0, *) {
			new.allowsPersistentDNS = storedRequest.allowsPersistentDNS
		}
		new.assumesHTTP3Capable = storedRequest.assumesHTTP3Capable
		new.requiresDNSSECValidation = storedRequest.requiresDNSSECValidation

		return new
	}
}
