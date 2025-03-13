import Foundation
import SwiftPizzaSnips

@dynamicMemberLookup
public enum NetworkRequest: Sendable {
	case upload(UploadEngineRequest, payload: UploadFile)
	case general(GeneralEngineRequest)

	private var metadata: EngineRequestMetadata {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest.metadata
			case .general(let generalEngineRequest):
				generalEngineRequest.metadata
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest.metadata = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .general(var generalEngineRequest):
				generalEngineRequest.metadata = newValue
				self = .general(generalEngineRequest)
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
