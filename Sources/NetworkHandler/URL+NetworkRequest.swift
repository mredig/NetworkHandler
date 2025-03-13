import Foundation

public extension URL {
	var downloadRequest: GeneralEngineRequest {
		GeneralEngineRequest(url: self)
	}

	var uploadRequest: UploadEngineRequest {
		UploadEngineRequest(url: self)
	}
}
