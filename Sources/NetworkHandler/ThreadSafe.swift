import Foundation

enum NH {
	@propertyWrapper
	public struct ThreadSafe<T> {
		
		private let queue: DispatchQueue
		private var _wrappedValue: T?
		public var wrappedValue: T  {
			get {
				queue.sync {
					guard let value = _wrappedValue else {
						fatalError("Can't access wrapped value before it's initialized!")
					}
					return value
				}
			}
			set {
				queue.sync {
					_wrappedValue = newValue
				}
			}
		}
		
		public init(wrappedValue: T, queue: DispatchQueue = DispatchQueue(label: "\(T.self)-queue")) {
			self._wrappedValue = wrappedValue
			self.queue = queue
		}
		
		public init(queue: DispatchQueue = DispatchQueue(label: "\(T.self)-queue")) {
			self.queue = queue
		}
	}
}
