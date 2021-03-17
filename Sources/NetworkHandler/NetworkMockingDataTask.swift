import Foundation

/// Conforms to `NetworkLoadingTask`, which in turn is designed to be similar to `URLSessionDataTask`
public class NetworkMockingDataTask: NetworkLoadingTaskEditor {
	public var priority: Float = 0.5

	public let progress = Progress(totalUnitCount: 0)

	private var completionClosures: [NetworkLoadingClosure] = [] {
		didSet {
			runCompletion()
		}
	}

	public var result: Result<Data?, Error>?

	typealias ServerSideSimulationHandler = NetworkMockingSession.ServerSideSimulationHandler

	private static let queue = DispatchQueue(label: "finishedQueue")
	@NH.ThreadSafe(queue: NetworkMockingDataTask.queue) private var _status: NetworkLoadingTaskStatus = .suspended
	public private(set) var status: NetworkLoadingTaskStatus {
		get { _status }
		set {
			_status = newValue
			runCompletion()
		}
	}

	private let simHandler: () -> Void

	public let mockDelay: TimeInterval

	init(mockDelay: TimeInterval, simHandler: @escaping () -> Void) {
		self.simHandler = simHandler
		self.mockDelay = mockDelay
	}

	private func runCompletion() {
		guard status == .completed else { return }
		completionClosures.forEach { $0(self) }
	}

	public func resume() {
		status = .running

		DispatchQueue.global().asyncAfter(deadline: .now() + mockDelay) {
			guard self.status == .running else { return }
			self.status = .completed
			self.simHandler()
		}
	}

	public func cancel() {
		status = .canceling
	}

	public func suspend() {
		status = .suspended
	}

	public func onProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self { self }

	public func onCompletion(_ perform: @escaping NetworkLoadingClosure) -> Self {
		completionClosures.append(perform)
		return self
	}

	public func setResult(_ result: Result<Data?, Error>) {
		self.result = result
	}
}
