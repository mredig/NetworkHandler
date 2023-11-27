// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var products: [Product] = [
	.library(
		name: "NetworkHandler",
		targets: ["NetworkHandler"]),
	.library(
		name: "NetworkHalpers",
		targets: ["NetworkHalpers"]),
]

var nhDeps: [Target.Dependency] = [
	.product(name: "Crypto", package: "swift-crypto"),
	"NetworkHalpers",
	"SaferContinuation",
	"Swiftwood",
]

var nhTestsDeps: [Target.Dependency] = [
	"NetworkHandler",
	"TestSupport",
	"PizzaMacros",
]
#if !os(Linux)
nhDeps.append("Swizzles")
nhTestsDeps.append("Swizzles")
#endif
var targets: [Target] = [
	.target(
		name: "NetworkHandler",
		dependencies: nhDeps),
	.target(
		name: "NetworkHalpers",
		dependencies: [
			//				"CryptoSwift",
			"Swiftwood",
		]),
	.target(
		name: "TestSupport",
		dependencies: [
			"NetworkHandler",
			"SwiftlyDotEnv",
		]),
	.testTarget(
		name: "NetworkHandlerTests",
		dependencies: nhTestsDeps),
	.testTarget(
		name: "NetworkHalpersTests",
		dependencies: [
			"NetworkHalpers",
			"TestSupport",
			"PizzaMacros",
		]),
]
#if !os(Linux)
products.append(.library(name: "Swizzles", targets: ["Swizzles"]))
targets.append(.target(name: "Swizzles",  publicHeadersPath: "include", cSettings: [.headerSearchPath(".")]))
#endif

let package = Package(
	name: "NetworkHandler",
	platforms: [
		.macOS(.v12),
		.iOS(.v15),
		.tvOS(.v15),
		.watchOS(.v8),
	],
	products: products,
	dependencies: [
		.package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.0.0")),
		.package(url: "https://github.com/mredig/SaferContinuation.git", .upToNextMinor(from: "1.3.0")),
		.package(url: "https://github.com/mredig/Swiftwood.git", .upToNextMajor(from: "0.4.0")),
		.package(url: "https://github.com/mredig/PizzaMacros.git", .upToNextMinor(from: "0.1.0")),
		.package(url: "https://github.com/mredig/SwiftlyDotEnv.git", .upToNextMinor(from: "0.2.3")),
	],
	targets: targets
)
