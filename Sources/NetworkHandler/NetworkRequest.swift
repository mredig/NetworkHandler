import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public struct NetworkRequest {

	// MARK: - New Properties
	public private(set) var urlRequest: URLRequest
	public var expectedResponseCodes: Set<Int>

	// MARK: - Upgraded Properties
	public var httpMethod: HTTPMethod? {
		get { urlRequest.method }
		set { urlRequest.method = newValue }
	}

	// MARK: - Mirrored Properties
	public var cachePolicy: URLRequest.CachePolicy {
		get { urlRequest.cachePolicy }
		set { urlRequest.cachePolicy = newValue }
	}

	public var url: URL? {
		get { urlRequest.url }
		set { urlRequest.url = newValue }
	}
	public var httpBody: Data? {
		get { urlRequest.httpBody }
		set { urlRequest.httpBody = newValue }
	}
	public var httpBodyStream: InputStream? {
		get { urlRequest.httpBodyStream }
		set { urlRequest.httpBodyStream = newValue }
	}
	public var mainDocumentURL: URL? {
		get { urlRequest.mainDocumentURL }
		set { urlRequest.mainDocumentURL = newValue }
	}

	public var allHeaderFields: [String: String]? {
		get { urlRequest.allHTTPHeaderFields }
		set { urlRequest.allHTTPHeaderFields = newValue }
	}

	public var timeoutInterval: TimeInterval {
		get { urlRequest.timeoutInterval }
		set { urlRequest.timeoutInterval = newValue }
	}
	public var httpShouldHandleCookies: Bool {
		get { urlRequest.httpShouldHandleCookies }
		set { urlRequest.httpShouldHandleCookies = newValue }
	}
	public var httpShouldUsePipelining: Bool {
		get { urlRequest.httpShouldUsePipelining }
		set { urlRequest.httpShouldUsePipelining = newValue }
	}
	public var allowsCellularAccess: Bool {
		get { urlRequest.allowsCellularAccess }
		set { urlRequest.allowsCellularAccess = newValue }
	}

	public var networkServiceType: URLRequest.NetworkServiceType {
		get { urlRequest.networkServiceType }
		set { urlRequest.networkServiceType = newValue }
	}

	#if !os(Linux)
	public var allowsExpensiveNetworkAccess: Bool {
		get { urlRequest.allowsExpensiveNetworkAccess }
		set { urlRequest.allowsExpensiveNetworkAccess = newValue }
	}
	public var allowsConstrainedNetworkAccess: Bool {
		get { urlRequest.allowsConstrainedNetworkAccess }
		set { urlRequest.allowsConstrainedNetworkAccess = newValue }
	}
	#endif

	/**
	Default encoder used to encode with the `encodeData` function. Changes here will reflect all request that don't provide their own encoder going forward.

	Default value is `JSONEncoder()` along with all of its defaults.

	This value is just a convenient access to `URLRequest.defaultEncoder` from `NetworkHaalper`. If you change one, they are both updated.
	*/
	public static var defaultEncoder: NHEncoder {
		get { URLRequest.defaultEncoder }
		set { URLRequest.defaultEncoder = newValue }
	}

	/**
	Encoder used to encode with the `encodeData` function. The default value is a reference to
	`NetworkRequest.defaultEncoder`, therefore changes will affect all encodings using the default, going forward.

	Either provide a new encoder for one off changes in encoding strategy, or standardize on a single stragegy for
	all encodings, set through `NetworkRequest.defaultEncoder`. For example, if an endpoint requires *all* variables
	to be encoded in snake case, you can set
	```
	(NetworkRequest.defaultEncoder as? JSONEncoder)?.keyEncodingStrategy = .convertToSnakeCase
	```
	and all unmodified future requests using `setJson` will do so. However, if any certain endpoint differs
	from the standard strategy, you can provide a new `JSONEncoder` (or really anything that conforms to `NHEncoder`)
	in a single instance of a NetworkRequest.
	*/
	public lazy var encoder: NHEncoder = { NetworkRequest.defaultEncoder }()

	/**
	Default decoder used to decode data received back from a `NetworkHandler.transferMahCodableDatas`. Changes here will reflect all request that don't
	provide their own decoder going forward.

	Default value is `JSONDecoder()` along with all of its defaults.
	*/
	public static var defaultDecoder: NHDecoder = JSONDecoder()
	/**
	Decoder used to decode data received back from a `NetworkHandler.transferMahCodableDatas`. The default value is a
	reference to `NetworkRequest.defaultDecoder`, therefore changes will affect all decodings using the default, going forward.

	Either provide a new decoder for one off changes in decoding strategy, or standardize on a single stragegy for
	all decodings, set through `NetworkRequest.defaultDecoder`. For example, if an endpoint requires *all* variables
	to be decoded from snake case, you can set
	```
	(NetworkRequest.defaultDecoder as? JSONDecoder)?.keyDecodingStrategy = .convertFromSnakeCase
	```
	and all unmodified future requests providing Decodable data will do so. However, if any certain endpoint differs
	from the standard strategy, you can provide a new `JSONDecoder` (or really anything that conforms to `NHDecoder`)
	in a single instance of a NetworkRequest.
	*/
	public var decoder: NHDecoder = NetworkRequest.defaultDecoder


	// MARK: - Lifecycle
	public init(_ request: URLRequest, expectedResponseCodes: Set<Int> = [200]) {
		self.urlRequest = request
		self.expectedResponseCodes = expectedResponseCodes
	}

	// MARK: - Methods
	public mutating func addValue(_ headerValue: HTTPHeaderValue, forHTTPHeaderField key: HTTPHeaderKey) {
		urlRequest.addValue(headerValue, forHTTPHeaderField: key)
	}

	public mutating func setValue(_ headerValue: HTTPHeaderValue?, forHTTPHeaderField key: HTTPHeaderKey) {
		urlRequest.setValue(headerValue, forHTTPHeaderField: key)
	}

	public func value(forHTTPHeaderField key: HTTPHeaderKey) -> String? {
		urlRequest.value(forHTTPHeaderField: key)
	}

	/// Sets `.httpBody` data to the result of encoding an encodable object passed in. If successful, returns the data.
	@discardableResult public mutating func encodeData<EncodableType: Encodable>(_ encodableType: EncodableType) throws -> Data {
		try urlRequest.encodeData(encodableType, encoder: encoder)
	}
}

public extension NetworkRequest {
	mutating func setContentType(_ contentType: HTTPHeaderValue) {
		urlRequest.setValue(contentType, forHTTPHeaderField: .contentType)
	}

	mutating func setAuthorization(_ value: HTTPHeaderValue) {
		urlRequest.setValue(value, forHTTPHeaderField: .authorization)
	}
}

extension Set: ExpressibleByIntegerLiteral where Element: FixedWidthInteger {

	public init(integerLiteral value: Int) {
		self.init()
		self.insert(Element(value))
	}

	public mutating func insert(_ array: [Element]) {
		Set(array).forEach { insert($0) }
	}

	public mutating func insertRange(_ range: ClosedRange<Element>) {
		Set(range).forEach { insert($0) }
	}
}
