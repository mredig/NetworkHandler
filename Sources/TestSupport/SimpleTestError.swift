public struct SimpleTestError: Error {
	public let message: String

	public init(message: String) {
		self.message = message
	}
}
