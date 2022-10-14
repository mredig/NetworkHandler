// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkHandler",
	platforms: [
		.macOS(.v12),
		.iOS(.v15),
		.tvOS(.v15),
		.watchOS(.v8),
	],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "NetworkHandler",
            targets: ["NetworkHandler"]),
		.library(
			name: "NetworkHalpers",
			targets: ["NetworkHalpers"]),
		.library(
			name: "Swizzles",
			targets: ["Swizzles"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-crypto.git", .upToNextMinor(from: "2.0.0")),
		.package(url: "https://github.com/mredig/SaferContinuation.git", .upToNextMinor(from: "1.1.5")),
		.package(url: "https://github.com/KnowMeGit/Swiftwood.git", .upToNextMinor(from: "0.1.2")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
		.target(
			name: "Swizzles",
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("."),
			]
		),
        .target(
            name: "NetworkHandler",
            dependencies: [
				.product(name: "Crypto", package: "swift-crypto"),
				"NetworkHalpers",
				"SaferContinuation",
				"Swiftwood",
			]),
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
			]),
        .testTarget(
            name: "NetworkHandlerTests",
            dependencies: ["NetworkHandler", "TestSupport", "Swizzles"]),
		.testTarget(
			name: "NetworkHalpersTests",
			dependencies: ["NetworkHalpers", "TestSupport"]),
    ]
)
