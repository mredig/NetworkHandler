extension HTTPHeaders {
	public struct Header: Hashable, Sendable, Codable {
		public let key: Key
		public let value: Value

		public init(key: Key, value: Value) {
			self.key = key
			self.value = value
		}
	}
}
