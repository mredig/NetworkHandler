import Testing
import Foundation
import NetworkHandler
import NetworkHandlerURLSessionEngine
import TestSupport
import PizzaMacros

struct EngineRequestMetadata_URLRequestProperties {
	let testURL = #URL("https://s3.wasabisys.com/network-handler-tests/images/lighthouse.jpg")

	@Test func cachePolicy() async throws {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.cachePolicy == plainURLRequest.cachePolicy)

		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		#expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
		#expect(request.urlRequest.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
		#expect(request.cachePolicy != plainURLRequest.cachePolicy)
	}

	@Test func mainDocumentURL() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.mainDocumentURL == plainURLRequest.mainDocumentURL)

		let fooURL = testURL.appending(component: "floooblarrr")
		request.mainDocumentURL = fooURL
		#expect(request.mainDocumentURL == fooURL)
		#expect(request.mainDocumentURL != plainURLRequest.mainDocumentURL)
		#expect(request.urlRequest.mainDocumentURL == fooURL)
	}

	@Test func httpShouldHandleCookies() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.httpShouldHandleCookies == plainURLRequest.httpShouldHandleCookies)

		request.httpShouldHandleCookies = false
		#expect(request.httpShouldHandleCookies == false)
		#expect(request.urlRequest.httpShouldHandleCookies == false)
		#expect(request.httpShouldHandleCookies != plainURLRequest.httpShouldHandleCookies)
	}

	@Test func httpShouldUsePipelining() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.httpShouldUsePipelining == plainURLRequest.httpShouldUsePipelining)

		request.httpShouldUsePipelining = true
		#expect(request.httpShouldUsePipelining == true)
		#expect(request.urlRequest.httpShouldUsePipelining == true)
		#expect(request.httpShouldUsePipelining != plainURLRequest.httpShouldUsePipelining)
	}

	@Test func allowsCellularAccess() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsCellularAccess == plainURLRequest.allowsCellularAccess)

		request.allowsCellularAccess = false
		#expect(request.allowsCellularAccess == false)
		#expect(request.urlRequest.allowsCellularAccess == false)
		#expect(request.allowsCellularAccess != plainURLRequest.allowsCellularAccess)
	}

	@Test func allowsConstrainedNetworkAccess() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsConstrainedNetworkAccess == plainURLRequest.allowsConstrainedNetworkAccess)

		request.allowsConstrainedNetworkAccess = false
		#expect(request.allowsConstrainedNetworkAccess == false)
		#expect(request.urlRequest.allowsConstrainedNetworkAccess == false)
		#expect(request.allowsConstrainedNetworkAccess != plainURLRequest.allowsConstrainedNetworkAccess)
	}

	@Test func allowsExpensiveNetworkAccess() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsExpensiveNetworkAccess == plainURLRequest.allowsExpensiveNetworkAccess)

		request.allowsExpensiveNetworkAccess = false
		#expect(request.allowsExpensiveNetworkAccess == false)
		#expect(request.urlRequest.allowsExpensiveNetworkAccess == false)
		#expect(request.allowsExpensiveNetworkAccess != plainURLRequest.allowsExpensiveNetworkAccess)
	}

	@Test func networkServiceType() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.networkServiceType == plainURLRequest.networkServiceType)

		request.networkServiceType = .video
		#expect(request.networkServiceType == .video)
		#expect(request.urlRequest.networkServiceType == .video)
		#expect(request.networkServiceType != plainURLRequest.networkServiceType)
	}

	@Test func attribution() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.attribution == plainURLRequest.attribution)

		request.attribution = .user
		#expect(request.attribution == .user)
		#expect(request.urlRequest.attribution == .user)
		#expect(request.attribution != plainURLRequest.attribution)
	}

	@available(macOS 15.0, *)
	@Test func allowsPersistentDNS() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsPersistentDNS == plainURLRequest.allowsPersistentDNS)

		request.allowsPersistentDNS = true
		#expect(request.allowsPersistentDNS == true)
		#expect(request.urlRequest.allowsPersistentDNS == true)
		#expect(request.allowsPersistentDNS != plainURLRequest.allowsPersistentDNS)
	}

	@Test func assumesHTTP3Capable() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.assumesHTTP3Capable == plainURLRequest.assumesHTTP3Capable)

		request.assumesHTTP3Capable = true
		#expect(request.assumesHTTP3Capable == true)
		#expect(request.urlRequest.assumesHTTP3Capable == true)
		#expect(request.assumesHTTP3Capable != plainURLRequest.assumesHTTP3Capable)
	}

	@Test func requiresDNSSECValidation() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.requiresDNSSECValidation == plainURLRequest.requiresDNSSECValidation)

		request.requiresDNSSECValidation = true
		#expect(request.requiresDNSSECValidation == true)
		#expect(request.urlRequest.requiresDNSSECValidation == true)
		#expect(request.requiresDNSSECValidation != plainURLRequest.requiresDNSSECValidation)
	}
}
