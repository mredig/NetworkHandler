import NetworkHalpers
import Foundation
import SwiftPizzaSnips

/// A network request primarily intended for sending larger amounts of data. It might include a large blob or chunked
/// stream for uploading. Progress is tracked for uploading AND downloading.
@dynamicMemberLookup
public struct UploadEngineRequest: Hashable, Sendable, Withable {
	package var metadata: EngineRequestMetadata

	public subscript<T>(dynamicMember member: WritableKeyPath<EngineRequestMetadata, T>) -> T {
		get { metadata[keyPath: member] }
		set { metadata[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<EngineRequestMetadata, T>) -> T {
		metadata[keyPath: member]
	}

	public init(
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPHeaders = [:],
		method: HTTPMethod = .get,
		url: URL,
		autogenerateRequestID: Bool = true
	) {
		self.metadata = EngineRequestMetadata(
			expectedResponseCodes: expectedResponseCodes,
			headers: headers,
			method: method,
			url: url,
			autogenerateRequestID: autogenerateRequestID)
	}
	
	public typealias ResponseCodes = EngineRequestMetadata.ResponseCodes
}
