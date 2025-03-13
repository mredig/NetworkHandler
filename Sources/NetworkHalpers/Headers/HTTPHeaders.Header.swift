extension HTTPHeaders {
	/// A single HTTP header, represented by a key-value pair.
	/// Encapsulates a key (`Key`) and its associated value (`Value`), providing type safety and protocol conformance.
	public struct Header: Hashable, Sendable, Codable {
		/// The key of the HTTP header.
		public let key: Key
		/// The value of the HTTP header.
		public let value: Value

		/// Creates a new HTTP header instance with the given key and value.
		/// - Parameters:
		///   - key: The key of the header. Must conform to `Header.Key`.
		///   - value: The value of the header. Must conform to `Header.Value`.
		public init(key: Key, value: Value) {
			self.key = key
			self.value = value
		}
	}
}
