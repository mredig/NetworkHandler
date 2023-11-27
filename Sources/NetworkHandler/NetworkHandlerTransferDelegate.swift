import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol NetworkHandlerTransferDelegate: URLSessionTaskDelegate {
	var task: URLSessionTask? { get set }
	func networkHandlerTaskDidStart(_ task: URLSessionTask)
	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double)
	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State)
}

extension NetworkHandlerTransferDelegate {
	func networkHandlerTaskDidStart(_ task: URLSessionTask) {}
	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double) {}
	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State) {}
}
