import Foundation

public struct DemoModel: Codable, Equatable {
	public let id: UUID
	public var title: String
	public var subtitle: String
	public var imageURL: URL

	public init(id: UUID = UUID(), title: String, subtitle: String, imageURL: URL) {
		self.id	= id
		self.title = title
		self.subtitle = subtitle
		self.imageURL = imageURL
	}
}
