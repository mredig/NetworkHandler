import Foundation
import SwiftPizzaSnips

public protocol NetworkEngine {
	typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
	func fetchNetworkData(from request: DownloadEngineRequest) async throws -> (EngineResponseHeader, ResponseBodyStream)
	func uploadNetworkData(with request: UploadEngineRequest) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, Error>,
		response: Task<EngineResponseHeader, Error>,
		responseBody: ResponseBodyStream)
}
