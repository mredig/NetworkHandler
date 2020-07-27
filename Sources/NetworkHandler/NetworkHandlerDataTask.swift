import Foundation

public class NetworkHandlerDataTask: NetworkLoadingTask {

	public let dataTask: URLSessionDataTask
	public var status: NetworkLoadingTaskStatus { dataTask.status }
	public var countOfBytesExpectedToReceive: Int64 { dataTask.countOfBytesExpectedToReceive }
	public var countOfBytesReceived: Int64 { dataTask.countOfBytesReceived }
	public var countOfBytesExpectedToSend: Int64 { dataTask.countOfBytesExpectedToSend }
	public var countOfBytesSent: Int64 { dataTask.countOfBytesSent }

	public var downloadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? {
		didSet {
			updateDownloadObserver()
		}
	}

	private var observer: NSKeyValueObservation?

	public init(_ dataTask: URLSessionDataTask, downloadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? = nil) {
		self.dataTask = dataTask
		self.downloadProgressUpdatedClosure = downloadProgressUpdatedClosure
		updateObservers()
	}

	private func updateObservers() {
		updateDownloadObserver()
	}

	private func updateDownloadObserver() {
		if downloadProgressUpdatedClosure == nil {
			observer?.invalidate()
			observer = nil
		} else {
			guard observer == nil else { return }
			observer = dataTask.observe(\.countOfBytesReceived, options: .new, changeHandler: { [weak self] (task, change) in
				guard let self = self else { return }
				self.handleUpdate()
			})
		}
	}

	public func resume() { dataTask.resume() }
	public func cancel() { dataTask.cancel() }
	public func suspend() { dataTask.suspend() }

	private func handleUpdate() {
		downloadProgressUpdatedClosure?(self)
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
