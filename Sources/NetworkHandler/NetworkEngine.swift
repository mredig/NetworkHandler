import Foundation
import SwiftPizzaSnips
import Logging

public typealias ResponseBodyStream = AsyncCancellableThrowingStream<[UInt8], Error>
public typealias UploadProgressStream = AsyncCancellableThrowingStream<Int64, Error>
public protocol NetworkEngine: Sendable, Withable {
	func fetchNetworkData(from request: DownloadEngineRequest, requestLogger: Logger?) async throws(NetworkError) -> (EngineResponseHeader, ResponseBodyStream)
	func uploadNetworkData(request: UploadEngineRequest, with payload: UploadFile, requestLogger: Logger?) async throws(NetworkError) -> (
		uploadProgress: UploadProgressStream,
		responseTask: ETask<EngineResponseHeader, NetworkError>,
		responseBody: ResponseBodyStream)

	static func isCancellationError(_ error: any Error) -> Bool
	static func isTimeoutError(_ error: any Error) -> Bool

	func shutdown()
}
