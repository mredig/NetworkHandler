# NetworkHandler

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmredig%2FNetworkHandler%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mredig/NetworkHandler)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmredig%2FNetworkHandler%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mredig/NetworkHandler)
NetworkHandler was originally created to reduce boilerplate when using `URLSession`. However, it's since grown into a unified, consistent abstraction built on top any engine conforming to `NetworkEngine`

By default, `NetworkEngine` implementations are provided for both `URLSession` if you have full access to `Foundation` (aka Apple platforms) and `AsyncHTTPClient` when you don't (or do, I'm not your mom). 


### Getting Started

1. Add the line 
	```swift 
	.package(url: "https://github.com/mredig/NetworkHandler.git", from: "3.0.0"))
	``` 
	to the appropriate section of your Package.swift
1. Add the dependency `NetworkHandlerURLSessionEngine` or `NetworkHandlerAHCEngine`, whichever you wish to use (The URLSession engine is unavailable on Linux) to your target.
1. Add `import NetworkHandler` to the top of any file you with to use it in
1. Here's a simple demo usage:

	```swift
	public struct DemoModel: Codable, Equatable, Sendable {
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

	func getDemoModel() async throws(NetworkError) {
		let urlSession = URLSession.asEngine(withConfiguration: .networkHandlerDefault)

		let networkHander = NetworkHandler(name: "Jimbob", engine: urlSession)

		let url = URL(string: "https://s3.wasabisys.com/network-handler-tests/coding/demoModel.json")

		let resultModel: DemoModel = try await nh.downloadMahCodableDatas(for: url.downloadRequest).decoded

		print(resultModel)
	}
	```



Further documentation is available on [SwiftPackageIndex](https://swiftpackageindex.com/mredig/NetworkHandler/main/documentation/networkhandler)