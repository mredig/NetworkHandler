import NetworkHalpers
import Foundation

// To rename to NetworkRequest, but leaving original in place for now
public struct EngineRequest: Hashable, Sendable {
	public struct ResponseCodes: Hashable, Sendable, RawRepresentable, ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral {
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

	public var payload: Payload

	public final class StreamProvider: Sendable, Hashable {
		public typealias Block = @Sendable (_ startOffset: Int, _ requestedByteCount: Int) async throws -> Data?
		public let block: Block

		public init(block: @escaping Block) {
			self.block = block
		}

		public static func == (lhs: EngineRequest.StreamProvider, rhs: EngineRequest.StreamProvider) -> Bool {
			lhs === rhs
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(Unmanaged.passUnretained(self).toOpaque())
		}
	}

	public enum UploadFile: Hashable, Sendable {
		case localFile(URL)
		case data(Data)
		case streamProvider(StreamProvider)
	}
	public enum Payload: Hashable, Sendable {
		case file(UploadFile)
		case data(Data?)

		var data: Data? {
			guard case .data(let data) = self else {
				return nil
			}
			return data
		}
	}

	public var timeoutInterval: TimeInterval = 60

	private var extensionStorage: [String: AnyHashable] = [:]

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

	/**
	Default encoder used to encode with the `encodeData` function.

	Default value is `JSONEncoder()` along with all of its defaults. Being that this is a static property, it will affect *all* instances.
	*/
	public static var defaultEncoder: NHEncoder = JSONEncoder()

	/**
	Default decoder used to decode data received from this request.

	Default value is `JSONDecoder()` along with all of its defaults. Being that this is a static property, it will affect *all* instances.
	*/
	public static var defaultDecoder: NHDecoder = JSONDecoder()

	public init(
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPHeaders = [:],
		method: HTTPMethod = .get,
		url: URL,
		payload: Payload = .data(nil)
	) {
		self.expectedResponseCodes = expectedResponseCodes
		self.headers = headers
		self.method = method
		self.url = url
		self.payload = payload
	}

	/// Sets `payload` data to the result of encoding an encodable object passed in. If successful, returns the data.
	@discardableResult
	public mutating func encodeData<EncodableType: Encodable>(_ encodableType: EncodableType, withEncoder encoder: NHEncoder? = nil) throws -> Data {
		let encoder = encoder ?? EngineRequest.defaultEncoder

		let data = try encoder.encode(encodableType)

		self.payload = .data(data)

		return data
	}
}
