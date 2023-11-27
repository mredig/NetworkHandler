import Foundation
#if canImport(FoundationNetworking)
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
