import SwiftPizzaSnips

/// While, in theory, if you cancel the Task that's running the NetworkHandler operation,
/// it should also cancel all its children. In practice, this *usually* happens.
///
/// The most reliable way to cancel the transfer of network data is to instead create, hold a
/// reference to, and pass a `NetworkCancellationToken` to the `NetworkHandler`
/// method you're using. Once you determine you need to cancel your operation, simply
/// call `.cancel()` on your reference and everything will fall in line!
public class NetworkCancellationToken: @unchecked Sendable {
	let lock = MutexLock()

	private var _isCancelled = false
	public private(set) var isCancelled: Bool {
		get { lock.withLock { _isCancelled } }
		set { lock.withLock { _isCancelled = newValue } }
	}

	private var _onCancel: () -> Void = {}
	var onCancel: () -> Void {
		get { lock.withLock { _onCancel } }
		set { lock.withLock { _onCancel = newValue } }
	}

	public init() {}

	public func cancel() {
		lock.withLock {
			_isCancelled = true
			_onCancel()
		}
	}

	public func checkIsCancelled() throws(CancellationError) {
		try lock.withLock { () throws(CancellationError) -> Void in
			guard _isCancelled == false else { throw CancellationError() }
		}
	}
}
