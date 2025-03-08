/// A (hopefully) temporary stand in for `Task`. Currently, `Task` only supports throwing `any Error`, but this project
/// has a goal for typed throws. This abstracts away the need to manually verify the thrown error conforms to
/// `Failure` at the call site and instead just lets you make the `ETask` properly typed in the first place.
/// (`ETask` is short for "typedError-Task")
///
/// Once `Swift.Task` gets updated with support for typed throws, this should be removed. In theory, it should allow
/// for a drop in replacement, assuming there's no significant API change to `Swift.Task`
public struct ETask<Success: Sendable, Failure: Error>: Sendable, Hashable {
	private let underlyingTask: Task<Success, Error>

	public var value: Success {
		get async throws(Failure) {
			do {
				return try await underlyingTask.value
			} catch {
				throw error as! Failure
			}
		}
	}

	public var result: Result<Success, Failure> {
		get async {
			do {
				let val = try await value
				return .success(val)
			} catch {
				return .failure(error)
			}
		}
	}

	public var isCancelled: Bool { underlyingTask.isCancelled }

	public init(
		priority: TaskPriority? = nil,
		@_implicitSelfCapture operation: sending @escaping @isolated(any) () async throws(Failure) -> Success
	) {
		self.init(detached: false, priority: priority, operation: operation)
	}

	private init(
		detached: Bool,
		priority: TaskPriority? = nil,
		@_implicitSelfCapture operation: sending @escaping @isolated(any) () async throws(Failure) -> Success
	) {
		if detached {
			underlyingTask = Task.detached(priority: priority, operation: operation)
		} else {
			underlyingTask = Task(priority: priority, operation: operation)
		}
	}

	public static func detached(
		priority: TaskPriority? = nil,
		operation: sending @escaping @isolated(any) () async throws(Failure) -> Success
	) -> ETask<Success, Failure> {
		Self.init(detached: true, priority: priority, operation: operation)
	}

	public func cancel() {
		underlyingTask.cancel()
	}
}
