public struct HTTPHeader: Hashable, Sendable {
	public let key: HTTPHeaderKey
	public let value: HTTPHeaderValue

	public init(key: HTTPHeaderKey, value: HTTPHeaderValue) {
		self.key = key
		self.value = value
	}
}
