//
//  NetworkCacheTests.swift
//  NetworkHandler
//
//  Created by Michael Redig on 5/10/20.
//  Copyright © 2020 Red_Egg Productions. All rights reserved.
//

@testable import NetworkHandler
import XCTest

open class NetworkHandlerBaseTest: XCTestCase {

	public func generateNetworkHandlerInstance() -> NetworkHandler {
		.init(name: "Test Network Handler")
	}

}
