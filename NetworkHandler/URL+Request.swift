//
//  URL+Request.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

public extension URL {
	var request: URLRequest {
		return URLRequest(url: self)
	}
}
