import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif

/**
 assists in version 2 uploads
 */
internal class UploadDelegate: NSObject, URLSessionTaskDelegate {
	static private let uploadDelegateLock = NSLock()

	private var delegates: [URLSessionTask: NetworkHandlerTransferDelegate] = [:]
	private var stateObservers: [URLSessionTask: NSKeyValueObservation] = [:]

	typealias DataPublisher = NHPublisher<Data, Error>
	private var dataPublishers: [URLSessionTask: DataPublisher] = [:]

	func dataPublisher(for task: URLSessionTask) -> DataPublisher {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }
		let pub = self.dataPublishers[task, default: DataPublisher()]
		self.dataPublishers[task] = pub
		return pub
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		let delegate = delegates[task]
		DispatchQueue.main.async {
			delegate?.networkHandlerTask(task, didProgress: Double(totalBytesSent) / Double(totalBytesExpectedToSend))
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		let pub = dataPublishers[task]
		defer {
			cleanUpTask(task)
		}

		if let error {
			pub?.send(completion: .failure(error))
		} else {
			pub?.send(completion: .finished)
		}
	}

	func addDelegate(_ delegate: NetworkHandlerTransferDelegate, for task: URLSessionTask) {
		delegates[task] = delegate

		let stateObserver = task
			.observe(\.state, options: .new) { [weak delegate] task, change in
				DispatchQueue.main.async {
					delegate?.networkHandlerTask(task, stateChanged: task.state)
				}
			}
		stateObservers[task] = stateObserver
		DispatchQueue.main.async {
			delegate.networkHandlerTask(task, stateChanged: task.state)
		}
	}

	func cleanUpTask(_ task: URLSessionTask) {
		delegates[task] = nil
		dataPublishers[task] = nil
		stateObservers[task]?.invalidate()
		stateObservers[task] = nil
	}
}

extension UploadDelegate: URLSessionDataDelegate {
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }
		self.dataPublishers[dataTask]?.send(data)
	}
}

extension UploadDelegate {
	enum DelegateTestError: Error {
		case stateObserversNotEmpty
		case dataPublishersNotEmpty
		case delegatesNotEmpty
	}

	func assertClean() throws {
		guard
			stateObservers.isEmpty
		else { throw DelegateTestError.stateObserversNotEmpty }

		guard
			dataPublishers.isEmpty
		else { throw DelegateTestError.dataPublishersNotEmpty }

		guard
			delegates.isEmpty
		else { throw DelegateTestError.delegatesNotEmpty }
	}
}
