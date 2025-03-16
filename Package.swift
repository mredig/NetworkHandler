// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var products: [Product] = [
	// Products define the executables and libraries produced by a package, and make them visible to other packages.
	.library(
		name: "NetworkHandler",
		targets: ["NetworkHandler"]),
	.library(
		name: "NetworkHalpers",
		targets: ["NetworkHalpers"]),
	.library(
		name: "NetworkHandlerAHCEngine",
		targets: ["NetworkHandlerAHCEngine"]),
	.library(
		name: "NetworkHandlerMockingEngine",
		targets: ["NetworkHandlerMockingEngine"])
]

var targets: [Target] = [
	.target(
		name: "NetworkHandler",
		dependencies: [
			.product(name: "Crypto", package: "swift-crypto"),
			"NetworkHalpers",
			"SwiftPizzaSnips",
			.product(name: "AsyncHTTPClient", package: "async-http-client"),
			.product(name: "Logging", package: "swift-log"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.target(
		name: "NetworkHandlerAHCEngine",
		dependencies: [
			"NetworkHandler",
			"NetworkHalpers",
			"SwiftPizzaSnips",
			.product(name: "AsyncHTTPClient", package: "async-http-client"),
			.product(name: "Logging", package: "swift-log"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.target(
		name: "NetworkHandlerMockingEngine",
		dependencies: [
			"NetworkHandler",
			"NetworkHalpers",
			"SwiftPizzaSnips",
			.product(name: "Logging", package: "swift-log"),
			.product(name: "Algorithms", package: "swift-algorithms"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.target(
		name: "NetworkHalpers",
		dependencies: [
			.product(name: "Crypto", package: "swift-crypto"),
			"SwiftPizzaSnips",
			.product(name: "Logging", package: "swift-log"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.target(
		name: "TestSupport",
		dependencies: [
			"PizzaMacros",
			"NetworkHandler",
			"SwiftlyDotEnv",
			"NetworkHandlerAHCEngine",
			"NetworkHandlerMockingEngine",
		],
		resources: [
			.copy("Resources")
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.testTarget(
		name: "NetworkHandlerTests",
		dependencies: [
			"NetworkHandler",
			"TestSupport",
			"PizzaMacros",
			.product(name: "Logging", package: "swift-log"),
			"NetworkHandlerMockingEngine",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.testTarget(
		name: "NetworkHandlerMockingTests",
		dependencies: [
			"NetworkHandler",
			"TestSupport",
			"PizzaMacros",
			.product(name: "Logging", package: "swift-log"),
			"NetworkHandlerMockingEngine",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.testTarget(
		name: "NetworkHandlerAHCTests",
		dependencies: [
			"NetworkHandler",
			"TestSupport",
			"PizzaMacros",
			.product(name: "Logging", package: "swift-log"),
			"NetworkHandlerAHCEngine",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.testTarget(
		name: "NetworkHalpersTests",
		dependencies: [
			"NetworkHalpers",
			"TestSupport",
			"PizzaMacros",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
]

#if !canImport(FoundationNetworking)
products.append(
	.library(
		name: "NetworkHandlerURLSessionEngine",
		targets: ["NetworkHandlerURLSessionEngine"]))

targets.append(
	.target(
		name: "NetworkHandlerURLSessionEngine",
		dependencies: [
			"NetworkHandler",
			"NetworkHalpers",
			"SwiftPizzaSnips",
			.product(name: "Logging", package: "swift-log"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]))

targets.append(
	.testTarget(
		name: "NetworkHandlerURLSessionTests",
		dependencies: [
			"NetworkHandler",
			"TestSupport",
			"PizzaMacros",
			.product(name: "Logging", package: "swift-log"),
			"NetworkHandlerURLSessionEngine",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]))
#endif

let package = Package(
	name: "NetworkHandler",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
		.tvOS(.v16),
		.watchOS(.v8),
	],
	products: products,
	dependencies: [
		.package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.0.0")),
		.package(url: "https://github.com/mredig/PizzaMacros.git", .upToNextMajor(from: "0.1.0")),
		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", .upToNextMajor(from: "0.4.35")),
		//		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", branch: "0.4.34h"),
		.package(url: "https://github.com/mredig/SwiftlyDotEnv.git", .upToNextMinor(from: "0.2.3")),
		.package(url: "https://github.com/swift-server/async-http-client", .upToNextMajor(from: "1.25.2")),
		.package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.6.2")),
		.package(url: "https://github.com/apple/swift-algorithms.git", .upToNextMajor(from: "1.2.1")),
		.package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.2")
	],
	targets: targets)
