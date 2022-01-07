import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public protocol NetworkHandlerTransferDelegate: AnyObject {
	func networkHandlerTaskDidStart(_ task: URLSessionTask)
	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double)
	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State)
}

extension NetworkHandlerTransferDelegate {
	func networkHandlerTaskDidStart(_ task: URLSessionTask) {}
	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double) {}
	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State) {}

}
