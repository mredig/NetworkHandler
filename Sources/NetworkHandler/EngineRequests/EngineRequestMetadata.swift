import NetworkHalpers
import Foundation
import SwiftPizzaSnips

/// Encapsulates shared metadata for a network engine request, such as headers, response codes,
/// HTTP method, and URL. Designed to be shared across related request types (`GeneralEngineRequest`
/// and `UploadEngineRequest`) for centralized management of common attributes.
public struct EngineRequestMetadata: Hashable, @unchecked Sendable, Withable {
	/// Defines the range of acceptable HTTP response status codes for a request.
	/// This type encapsulates response codes as a set of integers and provides
	/// conveniences for constructing it from individual integers, ranges, or arrays.
	///
	/// Example:
	/// ```swift
	/// let successCodes: ResponseCodes = [200, 201, 202]
	/// let any2xxCode = ResponseCodes(range: 200..<300)
	/// ```
	public struct ResponseCodes:
		Hashable,
		Sendable,
		Withable,
		RawRepresentable,
		ExpressibleByIntegerLiteral,
		ExpressibleByArrayLiteral {

		public var rawValue: Set<Int>

		public init(rawValue: Set<Int>) {
			self.rawValue = rawValue
		}

		public init(arrayLiteral elements: Int...) {
			self.init(rawValue: Set(elements))
		}

		public init(integerLiteral value: IntegerLiteralType) {
			self.init(rawValue: [value])
		}

		public init(range: Range<Int>) {
			self.init(rawValue: range.reduce(into: .init(), { $0.insert($1) } ))
		}
	}

	/// Specifies the range or list of HTTP response codes that are considered valid for this request.
	/// Responses falling outside this range may be treated as errors, depending on the network engine's logic.
	///
	/// Example:
	/// ```swift
	/// metadata.expectedResponseCodes = [200, 201, 202]
	/// metadata.expectedResponseCodes = ResponseCodes(range: 200..<300)
	/// ```
	public var expectedResponseCodes: ResponseCodes

	/// Gets or sets the expected size of the response payload in bytes via the `Content-Length` header.
	///
	/// When set, the `Content-Length` header is automatically updated.
	/// Setting this to `nil` removes the header from the metadata.
	public var expectedContentLength: Int? {
		get { headers[.contentLength].flatMap { Int($0.rawValue) } }
		set {
			guard let newValue else {
				headers[.contentLength] = nil
				return
			}
			headers[.contentLength] = "\(newValue)"
		}
	}

	public var headers: HTTPHeaders = []

	public var method: HTTPMethod = .get

	public var url: URL

	public var timeoutInterval: TimeInterval = 60

	private var extensionStorage: [String: AnyHashable] = [:]

	/// The unique ID used to identify this request. Follows the `X-Request-ID` HTTP header convention.
	///
	/// Automatically populated with a UUID string upon initialization if autogeneration is enabled.
	/// To disable this behavior, pass `autogenerateRequestID: false` during construction.
	///
	/// See [X-Request-ID](https://http.dev/x-request-id) for more info. Note that while it's an optional header,
	/// convention dictates that it should be the same when retrying a request.
	public var requestID: String? {
		get { headers.value(for: .xRequestID) }
		set {
			guard let newValue else {
				headers[.xRequestID] = nil
				return
			}
			headers[.xRequestID] = "\(newValue)"
		}
	}

	/// Stores platform or library-specific metadata in a key-value dictionary.
	///
	/// This mechanism allows extending `EngineRequestMetadata` with custom properties, especially
	/// in extensions (since extensions cannot introduce stored properties).
	///
	/// - Parameters:
	///   - value: The value to store. Setting `nil` removes the key from the storage.
	///   - key: A unique identifier for the metadata entry.
	///   
	/// For example, if you want to use Foundation's networking as your engine and use URLRequest, you could add
	///
	/// ```swift
	/// extension NetworkEngine {
	/// 	var allowsCellularAccess: Bool {
	/// 		get { (extensionStorageRetrieve(valueForKey: "allowsCellularAccess") ?? true }
	/// 		set { extensionStorage(store: newValue, with: "allowsCellularAccess") }
	/// 	}
	/// }
	/// ```
	public mutating func extensionStorage<T: Hashable & Sendable>(store value: T?, with key: String) {
		extensionStorage[key] = AnyHashable(value)
	}

	/// To support specialized properties for your platform, you can create an extension that stores its values here
	/// (since extensions only support computed properties)
	///
	/// For example, if you want to use Foundation's networking as your engine and use URLRequest, you could add
	///
	/// ```swift
	/// extension NetworkEngine {
	/// 	var allowsCellularAccess: Bool {
	/// 		get { (extensionStorageRetrieve(valueForKey: "allowsCellularAccess") ?? true }
	/// 		set { extensionStorage(store: newValue, with: "allowsCellularAccess") }
	/// 	}
	/// }
	/// ```
	public func extensionStorageRetrieve<T: Hashable & Sendable>(valueForKey key: String) -> T? {
		extensionStorage[key] as? T
	}

	/// Untyped variant of `extensionStorageRetrieve(valueForKey:)` to get whatever is stored, regardless of data type
	public func extensionStorageRetrieve(objectForKey key: String) -> Any? {
		extensionStorage[key]
	}

	public init(
		expectedResponseCodes: ResponseCodes = .init(range: 200..<299),
		headers: HTTPHeaders = [:],
		method: HTTPMethod = .get,
		url: URL,
		autogenerateRequestID: Bool
	) {
		self.expectedResponseCodes = expectedResponseCodes
		self.headers = headers
		self.method = method
		self.url = url
		guard autogenerateRequestID else { return }
		self.requestID = UUID().uuidString
	}
}
