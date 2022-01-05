import Foundation

public struct DummyType: Codable, Equatable {
	public let id: Int
	public let value: String
	public let other: Double

	public init(id: Int, value: String, other: Double) {
		self.id = id
		self.value = value
		self.other = other
	}
}
