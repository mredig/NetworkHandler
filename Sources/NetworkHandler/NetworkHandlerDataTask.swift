import Foundation

public class NetworkHandlerDataTask: NetworkLoadingTaskEditor {

	public var result: Result<Data?, Error>? {
		didSet {
			runCompletion()
		}
	}
	public let dataTask: URLSessionDataTask
	public var status: NetworkLoadingTaskStatus { dataTask.status }
	public var progress: Progress { dataTask.progress }

	public var priority: Float {
		get { dataTask.priority }
		set { dataTask.priority = newValue }
	}

	private var progressUpdatedClosures: [NetworkLoadingClosure] = []
	private var completionClosures: [NetworkLoadingClosure] = []

	private var progressObserver: NSKeyValueObservation?
	private var completionObserver: NSKeyValueObservation?

	public init(_ dataTask: URLSessionDataTask) {
		self.dataTask = dataTask

		setupObservers()
	}

	private func setupObservers() {
		setupProgressObserver()
		setupCompletionObserver()
	}

	private func setupProgressObserver() {
		guard progressObserver == nil else { return }

		progressObserver = progress.observe(\.fractionCompleted, options: .new) { [weak self] progress, change in
			self?.handleProgressUpdate()
		}
	}

	private func setupCompletionObserver() {
		guard completionObserver == nil else { return }
		completionObserver = dataTask.observe(\.state, options: .new, changeHandler: { [weak self] (task, change) in
			self?.runCompletion()
		})
	}

	public func resume() { dataTask.resume() }
	public func cancel() { dataTask.cancel() }
	public func suspend() { dataTask.suspend() }

	private func handleProgressUpdate() {
		progressUpdatedClosures.forEach { $0(self) }
	}

	private func runCompletion() {
		guard status == .completed, result != nil else { return }
		var reversedClosures = Array(completionClosures.reversed())
		completionClosures = []
		while let completionClosure = reversedClosures.popLast() {
			completionClosure(self)
		}
	}

	@discardableResult public func onProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self {
		progressUpdatedClosures.append(perform)
		return self
	}

	@discardableResult public func onCompletion(_ perform: @escaping NetworkLoadingClosure) -> Self {
		completionClosures.append(perform)
		runCompletion()
		return self
	}

	public func setResult(_ result: Result<Data?, Error>) {
		self.result = result
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
