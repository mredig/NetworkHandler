import Foundation

final class AtomicValue<T>: @unchecked Sendable {
	private let lock = NSLock()

	private var _value: T
	var value: T {
		get {
			lock.lock()
			defer { lock.unlock() }
			return _value
		}

		set {
			lock.lock()
			defer { lock.unlock() }
			_value = newValue
		}
	}

	init(value: T) {
		lock.lock()
		defer { lock.unlock() }
		self._value = value
	}
}

extension AtomicValue: CustomStringConvertible, CustomDebugStringConvertible {
	var description: String {
		"\(value)"
	}

	var debugDescription: String {
		"AtomicValue: \(value)"
	}
}
