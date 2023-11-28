import Foundation
@_exported import NetworkHalpers
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
assists in version 2 uploads
*/
internal class NHUploadDelegate: NSObject, URLSessionTaskDelegate {
	static private let uploadDelegateLock = NSLock()

	private var taskDelegates: [URLSessionTask: NetworkHandlerTransferDelegate] = [:]
	#if !canImport(FoundationNetworking)
	private var stateObservers: [URLSessionTask: NSKeyValueObservation] = [:]
	#endif
	private var inputStreams: [URLSessionTask: InputStream] = [:]

	typealias DataPublisher = NHPublisher<Data, Error>
	private var dataPublishers: [URLSessionTask: DataPublisher] = [:]

	typealias TaskKeepalive = NHPublisher<Void, Never>
	private var taskKeepalives: [URLSessionTask: TaskKeepalive] = [:]

	func dataPublisher(for task: URLSessionTask) -> DataPublisher {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }
		let pub = dataPublishers[task, default: DataPublisher()]
		dataPublishers[task] = pub
		return pub
	}

	func taskKeepalivePublisher(for task: URLSessionTask) -> TaskKeepalive {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }
		let pub = taskKeepalives[task, default: TaskKeepalive()]
		taskKeepalives[task] = pub
		return pub
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didSendBodyData bytesSent: Int64,
		totalBytesSent: Int64,
		totalBytesExpectedToSend: Int64
	) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }

		let delegate = taskDelegates[task]
		delegate?.networkHandlerTask(task, didProgress: Double(totalBytesSent) / Double(totalBytesExpectedToSend))

		taskKeepalives[task]?.send()
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }

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

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
	) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }

		let stream = inputStreams[task]

		completionHandler(stream)
	}

	func addTaskDelegate(_ delegate: NetworkHandlerTransferDelegate, for task: URLSessionTask) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }

		taskDelegates[task] = delegate

		#if !canImport(FoundationNetworking)
		let stateObserver = task
			.observe(\.state, options: .new) { [weak delegate] task, _ in
				DispatchQueue.main.async {
					delegate?.networkHandlerTask(task, stateChanged: task.state)
				}
			}
		stateObservers[task] = stateObserver
		DispatchQueue.main.async {
			delegate.networkHandlerTask(task, stateChanged: task.state)
		}
		#endif
	}

	func addInputStream(_ stream: InputStream, for task: URLSessionUploadTask) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }

		inputStreams[task] = stream
	}

	func cleanUpTask(_ task: URLSessionTask) {
		taskDelegates[task] = nil
		dataPublishers[task] = nil
		taskKeepalives[task] = nil
		#if !canImport(FoundationNetworking)
		stateObservers[task]?.invalidate()
		stateObservers[task] = nil
		#endif
		inputStreams[task] = nil
	}
}

extension NHUploadDelegate: URLSessionDataDelegate {
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		Self.uploadDelegateLock.lock()
		defer { Self.uploadDelegateLock.unlock() }

		self.dataPublishers[dataTask]?.send(data)
	}
}

extension NHUploadDelegate {
	enum DelegateTestError: Error {
		case stateObserversNotEmpty
		case dataPublishersNotEmpty
		case delegatesNotEmpty
		case keepAlivesNotEmpty
	}

	func assertClean() throws {
		#if !canImport(FoundationNetworking)
		guard
			stateObservers.isEmpty
		else { throw DelegateTestError.stateObserversNotEmpty }
		#endif

		guard
			dataPublishers.isEmpty
		else { throw DelegateTestError.dataPublishersNotEmpty }

		guard
			taskDelegates.isEmpty
		else { throw DelegateTestError.delegatesNotEmpty }

		guard
			taskKeepalives.isEmpty
		else { throw DelegateTestError.keepAlivesNotEmpty }
	}
}
