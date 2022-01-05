//
//  URL+Request.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif


public extension URL {
	/// Easy request generation.
	var request: NetworkRequest {
		NetworkRequest((URLRequest(url: self)))
	}
}
