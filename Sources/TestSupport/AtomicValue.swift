import Foundation

final public class AtomicValue<T>: @unchecked Sendable {
	private let lock = NSLock()

	private var _value: T
	public var value: T {
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

	public init(value: T) {
		lock.lock()
		defer { lock.unlock() }
		self._value = value
	}
}

extension AtomicValue: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String {
		"\(value)"
	}

	public var debugDescription: String {
		"AtomicValue: \(value)"
	}
}
