import NetworkHalpers
import Foundation

/// A network request primarily intended for sending larger amounts of data. It might include a large blob or chunked
/// stream for uploading. Progress is tracked for uploading AND downloading.
@dynamicMemberLookup
public struct UploadEngineRequest: Hashable, Sendable {
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
		url: URL
	) {
		self.metadata = EngineRequestMetadata(
			expectedResponseCodes: expectedResponseCodes,
			headers: headers,
			method: method,
			url: url)
	}
	public typealias ResponseCodes = EngineRequestMetadata.ResponseCodes

	public enum UploadFile: Hashable, Sendable {
		case localFile(URL)
		case data(Data)
		case streamProvider(StreamProvider)
	}
}
