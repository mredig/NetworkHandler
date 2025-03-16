import NetworkHalpers
import Foundation
import SwiftPizzaSnips

/// Represents an HTTP request for most HTTP interactions, such as sending or retrieving JSON or binary responses.
/// While upload progress is not tracked, download progress is monitored.
///
/// This is a lowst common denominator representation of an HTTP request. If you're conforming your own
/// engine to `NetworkEngine`, you'll most likely want to add a computed property or function to convert
/// a `GeneralEngineRequest` to the request type native to your engine.
@dynamicMemberLookup
public struct GeneralEngineRequest: Hashable, Sendable, Withable {
	/// Internal metadata used to store common HTTP request properties, such as HTTP headers, response codes,
	/// and URLs. This allows `GeneralEngineRequest` to provide a lightweight wrapper around core functionality
	/// without duplicating state or logic.
	package var metadata: EngineRequestMetadata

	public subscript<T>(dynamicMember member: WritableKeyPath<EngineRequestMetadata, T>) -> T {
		get { metadata[keyPath: member] }
		set { metadata[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<EngineRequestMetadata, T>) -> T {
		metadata[keyPath: member]
	}

	nonisolated(unsafe)
	private static var _defaultEncoder: NHEncoder = JSONEncoder()
	nonisolated(unsafe)
	private static var _defaultDecoder: NHDecoder = JSONDecoder()
	private static let coderLock = MutexLock()

	/// Default encoder used to encode with the `encodeData` function.
	///
	/// Default value is `JSONEncoder()` along with all of its defaults. Being that this
	/// is a static property, it will affect *all* instances.
	public static var defaultEncoder: NHEncoder {
		get { coderLock.withLock { _defaultEncoder } }
		set { coderLock.withLock { _defaultEncoder = newValue } }
	}

	/// Default decoder used to decode data received from this request.
	///
	/// Default value is `JSONDecoder()` along with all of its defaults. Being that this
	/// is a static property, it will affect *all* instances.
	public static var defaultDecoder: NHDecoder {
		get { coderLock.withLock { _defaultDecoder } }
		set { coderLock.withLock { _defaultDecoder = newValue } }
	}

	/// Optional raw data intended to be sent as part of the HTTP request body.
	/// This is commonly used for POST or PUT requests where structured data is required.
	/// To streamline JSON, PropertyList, or custom encoding, use the `encodeData` method.
	public var payload: Data?

	public init(
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPHeaders = [:],
		method: HTTPMethod = .get,
		url: URL,
		payload: Data? = nil,
		autogenerateRequestID: Bool = true
	) {
		self.payload = payload
		self.metadata = EngineRequestMetadata(
			expectedResponseCodes: expectedResponseCodes,
			headers: headers,
			method: method,
			url: url,
			autogenerateRequestID: autogenerateRequestID)
	}
	public typealias ResponseCodes = EngineRequestMetadata.ResponseCodes

	/// Encodes an object conforming to `Encodable` into a `Data` payload using the specified or default encoder.
	///
	/// Automatically updates the `payload` property with the resulting serialized data upon success.
	///
	/// - Parameters:
	///   - encodableType: The object to encode into the `payload`.
	///   - encoder: An optional encoder conforming to `NHEncoder`. Uses `defaultEncoder` if not explicitly provided.
	/// - Returns: The serialized data now stored in the request's `payload`.
	/// - Throws: Errors from the encoder if the object cannot be serialized.
	@discardableResult
	public mutating func encodeData<EncodableType: Encodable>(
		_ encodableType: EncodableType,
		withEncoder encoder: NHEncoder? = nil
	) throws -> Data {
		let encoder = encoder ?? GeneralEngineRequest.defaultEncoder

		let data = try encoder.encode(encodableType)

		self.payload = data

		return data
	}
}
