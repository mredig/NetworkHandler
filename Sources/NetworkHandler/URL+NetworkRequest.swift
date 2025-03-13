import Foundation

public extension URL {
	var generalRequest: GeneralEngineRequest {
		GeneralEngineRequest(url: self)
	}

	var uploadRequest: UploadEngineRequest {
		UploadEngineRequest(url: self)
	}
}
