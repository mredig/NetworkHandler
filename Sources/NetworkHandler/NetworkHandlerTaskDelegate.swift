import Foundation

@NHActor
public protocol NetworkHandlerTaskDelegate: Sendable {
	/// Called when the engine modifies the request in some way. This can happen, for example, on an upload when the `ContentLength` header gets set.
	func requestModified(from oldVersion: NetworkRequest, to newVersion: NetworkRequest)
	/// Only called on uploads
	func transferDidStart(for request: NetworkRequest)
	/// Only called on uploads
	func sentData(for request: NetworkRequest, totalByteCountSent: Int, totalExpectedToSend: Int?)
	/// Only called on uploads
	func sendingDataDidFinish(for request: NetworkRequest)
	func responseHeaderRetrieved(for request: NetworkRequest, header: EngineResponseHeader)
	/// Only called on downloads
	func responseBodyReceived(for request: NetworkRequest, bytes: Data)
	/// Only called on downloads
	func responseBodyReceived(for request: NetworkRequest, byteCount: Int, totalExpectedToReceive: Int?)
	func requestFinished(withError error: Error?)
}
