public enum UploadError: Error {
	case noServerResponseHeader
	case noInputStream
	case notTrackingRequestedTask
	case createStreamFromLocalFileFailed
}
