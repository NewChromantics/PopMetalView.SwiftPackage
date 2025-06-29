// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "PopMetalView",
	
	platforms: [
		.iOS(.v15),
		//.macOS(.v10_15)
		//.macOS(.v12)	//	for .overlay{} - revert to zstack if this is a problem
		.macOS(.v14)	//	for gizmo stroke/fill style
	],
	
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "PopMetalView",
			targets: ["PopMetalView"]),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "PopMetalView"),
		
	]
)

