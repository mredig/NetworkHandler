import Foundation

public class NetworkHandlerDataTask: NetworkLoadingTask {

	public let dataTask: URLSessionDataTask
	public var status: NetworkLoadingTaskStatus { dataTask.status }
	public var countOfBytesExpectedToReceive: Int64 { dataTask.countOfBytesExpectedToReceive }
	public var countOfBytesReceived: Int64 { dataTask.countOfBytesReceived }
	public var countOfBytesExpectedToSend: Int64 { dataTask.countOfBytesExpectedToSend }
	public var countOfBytesSent: Int64 { dataTask.countOfBytesSent }

	public var priority: Float = 0.5

	public var downloadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? {
		didSet {
			updateDownloadObserver()
		}
	}
	public var uploadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? {
		didSet {
			updateUploadObserver()
		}
	}

	private var downloadObserver: NSKeyValueObservation?
	private var uploadObserver: NSKeyValueObservation?

	public init(_ dataTask: URLSessionDataTask, downloadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? = nil) {
		self.dataTask = dataTask
		self.downloadProgressUpdatedClosure = downloadProgressUpdatedClosure
		updateObservers()
	}

	private func updateObservers() {
		updateDownloadObserver()
		updateUploadObserver()
	}

	private func updateDownloadObserver() {
		if downloadProgressUpdatedClosure == nil {
			downloadObserver?.invalidate()
			downloadObserver = nil
		} else {
			guard downloadObserver == nil else { return }
			downloadObserver = dataTask.observe(\.countOfBytesReceived, options: .new, changeHandler: { [weak self] (task, change) in
				guard let self = self else { return }
				self.handleDownloadUpdate()
			})
		}
	}

	private func updateUploadObserver() {
		if uploadProgressUpdatedClosure == nil {
			uploadObserver?.invalidate()
			uploadObserver = nil
		} else {
			guard uploadObserver == nil else { return }
			uploadObserver = dataTask.observe(\.countOfBytesSent, options: .new, changeHandler: { [weak self] (task, change) in
				guard let self = self else { return }
				self.handleUploadUpdate()
			})
		}
	}

	public func resume() { dataTask.resume() }
	public func cancel() { dataTask.cancel() }
	public func suspend() { dataTask.suspend() }

	private func handleDownloadUpdate() {
		downloadProgressUpdatedClosure?(self)
	}

	private func handleUploadUpdate() {
		uploadProgressUpdatedClosure?(self)
	}
}

extension URLSessionDataTask {
	var status: NetworkLoadingTaskStatus {
		switch state {
		case .running:
			return .running
		case .canceling:
			return .canceling
		case .suspended:
			return .suspended
		case .completed:
			return .completed
		@unknown default:
			fatalError("Unknown network loading status! \(state)")
		}
	}
}
