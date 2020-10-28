import Foundation

public class NetworkHandlerDataTask: NetworkLoadingTaskEditor {

	public var result: Result<Data?, Error>? {
		didSet {
			runCompletion()
		}
	}
	public let dataTask: URLSessionDataTask
	public var status: NetworkLoadingTaskStatus { dataTask.status }
	public var countOfBytesExpectedToReceive: Int64 { dataTask.countOfBytesExpectedToReceive }
	public var countOfBytesReceived: Int64 { dataTask.countOfBytesReceived }
	public var countOfBytesExpectedToSend: Int64 { dataTask.countOfBytesExpectedToSend }
	public var countOfBytesSent: Int64 { dataTask.countOfBytesSent }

	public var priority: Float {
		get { dataTask.priority }
		set { dataTask.priority = newValue }
	}

	private var downloadProgressUpdatedClosures: [NetworkLoadingClosure] = []
	private var uploadProgressUpdatedClosures: [NetworkLoadingClosure] = []
	private var completionClosures: [NetworkLoadingClosure] = []

	private var downloadObserver: NSKeyValueObservation?
	private var uploadObserver: NSKeyValueObservation?
	private var completionObserver: NSKeyValueObservation?

	public init(_ dataTask: URLSessionDataTask, downloadProgressUpdatedClosure: NetworkLoadingClosure? = nil) {
		self.dataTask = dataTask
		if let downloadClosure = downloadProgressUpdatedClosure {
			onDownloadProgressUpdated(downloadClosure)
		}
		setupObservers()
	}

	private func setupObservers() {
		setupDownloadObserver()
		setupUploadObserver()
		setupCompletionObserver()
	}

	private func setupDownloadObserver() {
			guard downloadObserver == nil else { return }
			downloadObserver = dataTask.observe(\.countOfBytesReceived, options: .new, changeHandler: { [weak self] (task, change) in
				guard let self = self else { return }
				self.handleDownloadUpdate()
			})
	}

	private func setupUploadObserver() {
		guard uploadObserver == nil else { return }
		uploadObserver = dataTask.observe(\.countOfBytesSent, options: .new, changeHandler: { [weak self] (task, change) in
			guard let self = self else { return }
			self.handleUploadUpdate()
		})
	}

	private func setupCompletionObserver() {
		guard completionObserver == nil else { return }
		completionObserver = dataTask.observe(\.state, options: .new, changeHandler: { [weak self] (task, change) in
			guard let self = self else { return }
			self.runCompletion()
		})
	}

	public func resume() { dataTask.resume() }
	public func cancel() { dataTask.cancel() }
	public func suspend() { dataTask.suspend() }

	private func handleDownloadUpdate() {
		downloadProgressUpdatedClosures.forEach { $0(self) }
	}

	private func handleUploadUpdate() {
		uploadProgressUpdatedClosures.forEach { $0(self) }
	}

	private func runCompletion() {
		guard status == .completed, result != nil else { return }
		var reversedClosures = Array(completionClosures.reversed())
		completionClosures = []
		while let completionClosure = reversedClosures.popLast() {
			completionClosure(self)
		}
	}

	@discardableResult public func onUploadProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self {
		uploadProgressUpdatedClosures.append(perform)
		return self
	}

	@discardableResult public func onDownloadProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self {
		downloadProgressUpdatedClosures.append(perform)
		return self
	}

	@discardableResult public func onCompletion(_ perform: @escaping NetworkLoadingClosure) -> Self {
		completionClosures.append(perform)
		runCompletion()
		return self
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
