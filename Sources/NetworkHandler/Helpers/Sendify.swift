import SwiftPizzaSnips

final package class Sendify<T>: @unchecked Sendable {
	public var value: T {
		get { lock.withLock { _value } }
		set { lock.withLock { _value = newValue } }
	}

	private var _value: T

	private let lock = MutexLock()

	public init(_ value: T) {
		lock.lock()
		defer { lock.unlock() }
		self._value = value
	}
}

extension Sendify: Equatable where T: Equatable {
	package static func == (lhs: Sendify<T>, rhs: Sendify<T>) -> Bool {
		lhs.value == rhs.value
	}
}
extension Sendify: Hashable where T: Hashable {
	package func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}
}
