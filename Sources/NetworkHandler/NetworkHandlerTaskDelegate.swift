import Foundation

@NHActor
public protocol NetworkHandlerTaskDelegate: Sendable {
	func transferDidStart(for request: NetworkRequest)
	func sentData(for request: NetworkRequest, byteCountSent: Int, totalExpectedToSend: Int?)
	func sendingDataDidFinish(for request: NetworkRequest)
	func responseHeaderRetrieved(for request: NetworkRequest, header: EngineResponseHeader)
	func responseBodyReceived(for request: NetworkRequest, bytes: Data)
	func responseBodyReceived(for request: NetworkRequest, byteCount: Int, totalExpectedToReceive: Int?)
	func requestFinished(withError error: Error?)
}
