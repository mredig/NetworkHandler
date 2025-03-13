import Foundation
import SwiftPizzaSnips

@dynamicMemberLookup
public enum NetworkRequest: Sendable {
	case upload(UploadEngineRequest, payload: UploadFile)
	case download(GeneralEngineRequest)

	private var metadata: EngineRequestMetadata {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest.metadata
			case .download(let generalEngineRequest):
				generalEngineRequest.metadata
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest.metadata = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .download(var generalEngineRequest):
				generalEngineRequest.metadata = newValue
				self = .download(generalEngineRequest)
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

extension NetworkRequest: Hashable, Withable {}
