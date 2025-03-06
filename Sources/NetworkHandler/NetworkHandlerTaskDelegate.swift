import Foundation

@NHActor
public protocol NetworkHandlerTaskDelegate: Sendable {
	/// Only called on uploads
	func transferDidStart(for request: NetworkRequest)
	/// Only called on uploads
	func sentData(for request: NetworkRequest, byteCountSent: Int, totalExpectedToSend: Int?)
	/// Only called on uploads
	func sendingDataDidFinish(for request: NetworkRequest)
	func responseHeaderRetrieved(for request: NetworkRequest, header: EngineResponseHeader)
	/// Only called on downloads
	func responseBodyReceived(for request: NetworkRequest, bytes: Data)
	/// Only called on downloads
	func responseBodyReceived(for request: NetworkRequest, byteCount: Int, totalExpectedToReceive: Int?)
	func requestFinished(withError error: Error?)
}
