import Foundation

public extension URL {
	var downloadRequest: DownloadEngineRequest {
		DownloadEngineRequest(url: self)
	}

	var uploadRequest: UploadEngineRequest {
		UploadEngineRequest(url: self)
	}
}
