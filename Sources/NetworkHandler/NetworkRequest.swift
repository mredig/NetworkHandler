import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@dynamicMemberLookup
public enum NetworkRequest: Sendable {
	case upload(UploadEngineRequest, payload: UploadFile)
	case download(DownloadEngineRequest)

	private var metadata: EngineRequestMetadata {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest.metadata
			case .download(let downloadEngineRequest):
				downloadEngineRequest.metadata
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest.metadata = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .download(var downloadEngineRequest):
				downloadEngineRequest.metadata = newValue
				self = .download(downloadEngineRequest)
			}
		}
	}

	public subscript<T>(dynamicMember member: WritableKeyPath<EngineRequestMetadata, T>) -> T {
		get { metadata[keyPath: member] }
		set { metadata[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<EngineRequestMetadata, T>) -> T {
		metadata[keyPath: member]
	}
}

extension NetworkRequest: Hashable {}
