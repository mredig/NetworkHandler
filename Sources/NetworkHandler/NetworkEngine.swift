import Foundation
import SwiftPizzaSnips
import Logging

public typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
public protocol NetworkEngine: Sendable, Withable {
	func fetchNetworkData(from request: DownloadEngineRequest, requestLogger: Logger?) async throws -> (EngineResponseHeader, ResponseBodyStream)
	func uploadNetworkData(request: UploadEngineRequest, with payload: UploadFile, requestLogger: Logger?) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, Error>,
		responseTask: Task<EngineResponseHeader, Error>,
		responseBody: ResponseBodyStream)

	func shutdown()
}
