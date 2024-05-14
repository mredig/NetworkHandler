import Foundation

extension NSLocking {
	public func withLock<R>(_ body: () throws -> R) rethrows -> R {
		lock()
		defer { unlock() }
		return try body()
	}
}
