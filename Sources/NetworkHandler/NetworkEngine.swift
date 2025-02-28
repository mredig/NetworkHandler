import Foundation
import SwiftPizzaSnips

public protocol NetworkEngine {
	typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
	func fetchNetworkData(from request: DownloadEngineRequest) async throws -> (EngineResponseHeader, ResponseBodyStream)
}
