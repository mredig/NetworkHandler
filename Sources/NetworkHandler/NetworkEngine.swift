import Foundation
import SwiftPizzaSnips
import Logging

public protocol NetworkEngine {
	typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
	func fetchNetworkData(from request: DownloadEngineRequest, requestLogger: Logger?) async throws -> (EngineResponseHeader, ResponseBodyStream)
	func uploadNetworkData(request: UploadEngineRequest, with payload: UploadFile, requestLogger: Logger?) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, Error>,
		response: Task<EngineResponseHeader, Error>,
		responseBody: ResponseBodyStream)

	func shutdown()
}
