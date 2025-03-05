import NetworkHalpers
import Foundation
import SwiftPizzaSnips

/// A network request primarily intended for retrieving data or sending small amounts of data.
/// Upload progress is ignored, but download progress is tracked.
@dynamicMemberLookup
public struct DownloadEngineRequest: Hashable, Sendable, Withable {
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
	/**
	Default encoder used to encode with the `encodeData` function.

	Default value is `JSONEncoder()` along with all of its defaults. Being that this is a static property, it will affect *all* instances.
	*/
	public static var defaultEncoder: NHEncoder {
		get { coderLock.withLock { _defaultEncoder } }
		set { coderLock.withLock { _defaultEncoder = newValue } }
	}

	/**
	Default decoder used to decode data received from this request.

	Default value is `JSONDecoder()` along with all of its defaults. Being that this is a static property, it will affect *all* instances.
	*/
	public static var defaultDecoder: NHDecoder {
		get { coderLock.withLock { _defaultDecoder } }
		set { coderLock.withLock { _defaultDecoder = newValue } }
	}

	public var payload: Data?

	public init(
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPHeaders = [:],
		method: HTTPMethod = .get,
		url: URL,
		payload: Data? = nil
	) {
		self.payload = payload
		self.metadata = EngineRequestMetadata(
			expectedResponseCodes: expectedResponseCodes,
			headers: headers,
			method: method,
			url: url)
	}
	public typealias ResponseCodes = EngineRequestMetadata.ResponseCodes

	/// Sets `payload` data to the result of encoding an encodable object passed in. If successful, returns the data.
	@discardableResult
	public mutating func encodeData<EncodableType: Encodable>(_ encodableType: EncodableType, withEncoder encoder: NHEncoder? = nil) throws -> Data {
		let encoder = encoder ?? DownloadEngineRequest.defaultEncoder

		let data = try encoder.encode(encodableType)

		self.payload = data

		return data
	}
}
