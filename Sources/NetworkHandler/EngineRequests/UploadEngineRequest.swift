import NetworkHalpers
import Foundation
import SwiftPizzaSnips

/// An HTTP request type designed specifically for uploading larger payloads, such as files or
/// large binary data. Unlike `DownloadEngineRequest`, this tracks both upload and download progress.
///
/// The request metadata is shared with `EngineRequestMetadata`, simplifying configuration for things
/// like headers and request IDs.
///
/// This is a lowst common denominator representation of an HTTP request. If you're conforming your own
/// engine to `NetworkEngine`, you'll most likely want to add a computed property or function to convert
/// a `UploadEngineRequest` to the request type native to your engine.
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
