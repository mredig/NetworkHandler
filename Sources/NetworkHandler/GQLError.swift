//
//  GQError.swift
//  NetworkHandler-iOS
//
//  Created by Michael Redig on 12/7/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif


struct GQLErrorContainer: Codable, Hashable {
	let errors: [GQLError]
}

public struct GQLError: Codable, Hashable {
	public let message: String
	public let path: [String]?
	public let locations: [GQLErrorLocation]?
	public let extensions: GQLErrorExtension
}

public struct GQLErrorExtension: Codable, Hashable {
	public let code: String
	public let exception: GQLErrorException?
}

public struct GQLErrorException: Codable, Hashable {
	public let errno: Int?
	public let code: String?
	public let syscall: String?
	public let path: String?
	public let stacktrace: [String]?
}

public struct GQLErrorLocation: Codable, Hashable {
	public let line: Int
	public let column: Int
}
