import NetworkHalpers
import Foundation
import SwiftPizzaSnips

/// Carries common networking request data, such as the url the request is for. 
public struct EngineRequestMetadata: Hashable, @unchecked Sendable, Withable {
	public struct ResponseCodes: Hashable, Sendable, Withable, RawRepresentable, ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral {
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
	}

	public var expectedResponseCodes: ResponseCodes

	public var headers: HTTPHeaders = []

	public var method: HTTPMethod = .get

	public var url: URL

	public var timeoutInterval: TimeInterval = 60

	private var extensionStorage: [String: AnyHashable] = [:]

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
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPHeaders = [:],
		method: HTTPMethod = .get,
		url: URL
	) {
		self.expectedResponseCodes = expectedResponseCodes
		self.headers = headers
		self.method = method
		self.url = url
	}
}
