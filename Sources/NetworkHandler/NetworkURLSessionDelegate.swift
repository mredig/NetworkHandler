import Combine
import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif

internal class TheDelegate: NSObject, URLSessionDelegate {
	static private let queue = OperationQueue()

	typealias DataPublisher = PassthroughSubject<Data, Error>
	private var publishers: [URLSessionTask: DataPublisher] = [:]

	func publisher(for task: URLSessionTask) -> DataPublisher {
		Self.queue.addOperationAndWaitUntilFinished {
			let pub = self.publishers[task, default: DataPublisher()]
			self.publishers[task] = pub
			return pub
		}
	}
}

extension TheDelegate: URLSessionTaskDelegate {
//	func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
//		<#code#>
//	}

//	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
//		<#code#>
//	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		let completion: Subscribers.Completion<Error>
		if let error = error {
			completion = .failure(error)
		} else {
			completion = .finished
		}
		Self.queue.addOperationAndWaitUntilFinished {
			self.publishers[task]?.send(completion: completion)
		}
	}
}

extension TheDelegate: URLSessionDataDelegate {
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		Self.queue.addOperationAndWaitUntilFinished {
			self.publishers[dataTask]?.send(data)
		}
	}
}

extension TheDelegate: URLSessionDownloadDelegate {
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		print("Got a download task to location: \(location)")
	}
}
