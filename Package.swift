// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let nhDeps = {
	var out: [Target.Dependency] = [
		.product(name: "Crypto", package: "swift-crypto"),
		"NetworkHalpers",
		"SaferContinuation",
		"Swiftwood",
		"SwiftPizzaSnips",
		.product(name: "AsyncHTTPClient", package: "async-http-client"),
	]

	#if os(Linux)
	out.append("NHLinuxSupport")
	#else
	out.append("Swizzles")
	#endif
	return out
}()

let nhTestDeps = {
	var out: [Target.Dependency] = [
		"NetworkHandler",
		"TestSupport",
		"PizzaMacros",
	]

	#if !os(Linux)
	out.append("Swizzles")
	#endif
	return out
}()

let targets = {
	var out: [Target] = [
		.target(
			name: "NetworkHandler",
			dependencies: nhDeps,
			swiftSettings: [
				.enableUpcomingFeature("BareSlashRegexLiterals")
			]),
		.target(
			name: "NetworkHalpers",
			dependencies: [
				.product(name: "Crypto", package: "swift-crypto"),
				"Swiftwood",
				"SwiftPizzaSnips",
			]),
		.target(
			name: "NHLinuxSupport"),
		.target(
			name: "TestSupport",
			dependencies: [
				"NetworkHandler",
				"SwiftlyDotEnv",
			]),
		.testTarget(
			name: "NetworkHandlerTests",
			dependencies: nhTestDeps),
		.testTarget(
			name: "NetworkHalpersTests",
			dependencies: [
				"NetworkHalpers",
				"TestSupport",
				"PizzaMacros",
			]),
	]

	#if !os(Linux)
	out.append(
		.target(
			name: "Swizzles",
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("."),
			]))
	#endif
	return out
}()

let products = {
	var out: [Product] = [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "NetworkHandler",
			targets: ["NetworkHandler"]),
		.library(
			name: "NetworkHalpers",
			targets: ["NetworkHalpers"]),
	]

	#if !os(Linux)
	out.append(
		.library(
			name: "Swizzles",
			targets: [
				"Swizzles",
			]))
	#endif
	return out
}()

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
		.package(url: "https://github.com/mredig/SaferContinuation.git", .upToNextMinor(from: "1.3.0")),
		.package(url: "https://github.com/mredig/Swiftwood.git", .upToNextMajor(from: "0.4.0")),
		.package(url: "https://github.com/mredig/PizzaMacros.git", .upToNextMajor(from: "0.1.0")),
//		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", .upToNextMajor(from: "0.4.0")),
		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", branch: "0.4.34d"),
		.package(url: "https://github.com/mredig/SwiftlyDotEnv.git", .upToNextMinor(from: "0.2.3")),
		.package(url: "https://github.com/swift-server/async-http-client", .upToNextMajor(from: "1.25.2"))
	],
	targets: targets)
