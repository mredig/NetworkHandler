import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif

/// Combine isn't available on Linux and there's not much of its functionality required for this package, so this is a small portion of Combine like functionality.
/// Definitely an internal class, not intended to be used outside of this package
class NHPublisher<MessageType, ErrorType: Error> {
	enum Completion {
		case finished
		case failure(ErrorType)
	}

	typealias MessageSink = (MessageType) -> Void
	private var valueSinks: [MessageSink] = []
	typealias CompletionSink = (Completion) -> Void
	private var completionSinks: [CompletionSink] = []

	private var isCompleted = false

	func send(_ message: MessageType) {
		guard isCompleted == false else { return }
		valueSinks.forEach {
			$0(message)
		}
	}

	func send(completion: Completion) {
		guard isCompleted == false else { return }
		isCompleted = true
		completionSinks.forEach {
			$0(completion)
		}
	}

	func sink(receiveValue: @escaping MessageSink, receiveCompletion: CompletionSink? = nil) {
		valueSinks.append(receiveValue)

		if let receiveCompletion = receiveCompletion {
			completionSinks.append(receiveCompletion)
		}
	}
}

internal class TheDelegate: NSObject, URLSessionDelegate {
	static private let queue = OperationQueue()

	typealias DataPublisher = NHPublisher<Data, Error>
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
		let completion: DataPublisher.Completion
		if let error = error {
			completion = .failure(error)
		} else {
			completion = .finished
		}
		Self.queue.addOperationAndWaitUntilFinished {
			let pub = self.publishers.removeValue(forKey: task)
			pub?.send(completion: completion)
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