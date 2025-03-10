import Foundation
import SwiftPizzaSnips

class TimeoutDebouncer: @unchecked Sendable {
	let timeoutDuration: TimeInterval

	private(set) var onTimeoutReached: @Sendable () -> Void

	private let lock = MutexLock()

	private var timeoutTask: Task<Void, Error>?
	private var isTimeoutReached = false
	private var isCancelled = false

	init(timeoutDuration: TimeInterval, onTimeoutReached: @escaping @Sendable () -> Void) {
		self.timeoutDuration = timeoutDuration
		self.onTimeoutReached = onTimeoutReached
	}

	func checkIn() {
		lock.withLock {
			timeoutTask?.cancel()
			timeoutTask = nil
			guard
				isCancelled == false,
				isTimeoutReached == false
			else { return }
			timeoutTask = Task {
				try await Task.sleep(for: .seconds(timeoutDuration))
				try Task.checkCancellation()
				performTimeoutActions()
			}
		}
	}

	private func performTimeoutActions() {
		lock.withLock {
			guard
				isCancelled == false,
				isTimeoutReached == false
			else { return }
			onTimeoutReached()
			isTimeoutReached = true
		}
	}

	func updateTimeoutAction(_ block: @escaping @Sendable () -> Void) {
		lock.withLock {
			onTimeoutReached = block
		}
	}

	func cancelTimeout() {
		lock.withLock {
			timeoutTask?.cancel()
			timeoutTask = nil
			isCancelled = true
		}
	}
}
