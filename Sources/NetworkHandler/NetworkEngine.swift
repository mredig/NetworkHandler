import Foundation
import SwiftPizzaSnips

public protocol NetworkEngine {
	typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
	func fetchNetworkData(from request: DownloadEngineRequest) async throws -> (EngineResponseHeader, ResponseBodyStream)
	func uploadNetworkData(request: UploadEngineRequest, with payload: UploadFile) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, Error>,
		response: Task<EngineResponseHeader, Error>,
		responseBody: ResponseBodyStream)

	func shutdown()
}
