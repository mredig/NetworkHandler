//
//  CodingHelpers.swift
//  NetworkHandler-iOS
//
//  Created by Michael Redig on 2/13/20.
//  Copyright © 2020 Red_Egg Productions. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif


/// Allows you to conform to this protocol to become compatible with `NetworkRequest.encodeData`
public protocol NHEncoder {
	func encode<T: Encodable>(_ encodable: T) throws -> Data
}

/// Allows you to conform to this protocol to become compatible with `NetworkHandler.transferMahCodableDatas`
public protocol NHDecoder {
	func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONEncoder: NHEncoder {}
extension PropertyListEncoder: NHEncoder {}
extension JSONDecoder: NHDecoder {}
extension PropertyListDecoder: NHDecoder {}
