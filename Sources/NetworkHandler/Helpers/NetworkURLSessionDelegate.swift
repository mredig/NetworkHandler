import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif

/// Combine isn't available on Linux and there's not much of its functionality required for this package, so this is an exceedingly simple portion of Combine like functionality.
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

	private let sendLock = NSLock()

	required init() {}

	func send(_ message: MessageType) {
		sendLock.lock()
		defer { sendLock.unlock() }
		guard isCompleted == false else { return }
		valueSinks.forEach {
			$0(message)
		}
	}

	func send(completion: Completion) {
		sendLock.lock()
		defer { sendLock.unlock() }
		guard isCompleted == false else { return }
		isCompleted = true
		completionSinks.forEach {
			$0(completion)
		}
	}

	@discardableResult func sink(receiveValue: @escaping MessageSink, receiveCompletion: CompletionSink? = nil) -> Self {
		valueSinks.append(receiveValue)

		if let receiveCompletion = receiveCompletion {
			completionSinks.append(receiveCompletion)
		}

		return self
	}

	func receive(on queue: DispatchQueue) -> Self {
		let newPub = Self()
		valueSinks.append { message in
			queue.async { newPub.send(message) }
		}

		completionSinks.append { completion in
			queue.async { newPub.send(completion: completion) }
		}

		return newPub
	}

	private var previousMessage: MessageType?
	/**
	- predicate
		A closure to evaluate whether two elements are equivalent, for purposes of filtering. Return true from this closure to indicate that the second element is a duplicate of the first.
	 */
	func removeDuplicates(by predicate: @escaping (MessageType, MessageType) -> Bool) -> Self {
		let newPub = Self()

		valueSinks.append({ [weak self] latestMessage in
			defer { self?.previousMessage = latestMessage }

			guard let previousMessage = self?.previousMessage else {
				newPub.send(latestMessage)
				return
			}

			if predicate(previousMessage, latestMessage) == false {
				newPub.send(latestMessage)
			}
		})
		return newPub
	}

	func removeDuplicates() -> Self where MessageType: Equatable {
		removeDuplicates { $0 == $1 }
	}
}

@NHActor
internal class TheDelegate: NSObject, URLSessionDelegate {
	static private let queue = OperationQueue()

	typealias DataPublisher = NHPublisher<Data, Error>
	private var dataPublishers: [URLSessionTask: DataPublisher] = [:]
	typealias ProgressPublisher = NHPublisher<(Int64, Int64), Never>
	private var progressPublishers: [URLSessionTask: ProgressPublisher] = [:]

	nonisolated override init() {
		super.init()
	}

	func dataPublisher(for task: URLSessionTask) -> DataPublisher {
		Self.queue.addOperationAndWaitUntilFinished {
			let pub = self.dataPublishers[task, default: DataPublisher()]
			self.dataPublishers[task] = pub
			return pub
		}
	}

	func progressPublisher(for task: URLSessionTask) -> ProgressPublisher {
		Self.queue.addOperationAndWaitUntilFinished {
			let pub = self.progressPublishers[task, default: ProgressPublisher()]
			self.progressPublishers[task] = pub
			return pub
		}
	}

	func cancelTracking(for task: URLSessionTask) {
		Self.queue.addOperationAndWaitUntilFinished {
			self.dataPublishers.removeValue(forKey: task)
			self.progressPublishers.removeValue(forKey: task)
		}
	}
}

/**
 assists in version 2 uploads
 */
internal class UploadDelegate: NSObject, URLSessionTaskDelegate {
	weak var delegate: NetworkHandlerTransferDelegate?

	private(set) weak var task: URLSessionTask?

	private weak var stateObserver: NSKeyValueObservation?

	let request: NetworkRequest

	init(delegate: NetworkHandlerTransferDelegate?, request: NetworkRequest) {
		self.delegate = delegate
		self.request = request
	}

	deinit {
		stateObserver?.invalidate()
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		setTask(task)

		delegate?.networkHandlerTask(task, didProgress: Double(totalBytesSent) / Double(totalBytesExpectedToSend))
	}

	private func setTask(_ task: URLSessionTask) {
		guard self.task == nil else { return }

		self.task = task
		task.priority = request.priority.rawValue
		delegate?.networkHandlerTaskDidStart(task)

		let stateObs = task.observe(\.state, options: .new) { [weak delegate] task, change in
			delegate?.networkHandlerTask(task, stateChanged: task.state)
		}
		self.stateObserver = stateObs
	}
}
extension TheDelegate: URLSessionTaskDelegate {
//	func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
//		<#code#>
//	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		Self.queue.addOperationAndWaitUntilFinished {
			self.progressPublishers[task]?.send((totalBytesSent, totalBytesExpectedToSend))
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		let completion: DataPublisher.Completion
		if let error = error {
			completion = .failure(error)
		} else {
			completion = .finished
		}
		Self.queue.addOperationAndWaitUntilFinished {
			let pub = self.dataPublishers.removeValue(forKey: task)
			log.veryVerbose("Completing task \(task.taskIdentifier) and publishing data publisher")
			pub?.send(completion: completion)

			let pub2 = self.progressPublishers.removeValue(forKey: task)
			log.veryVerbose("Completing task \(task.taskIdentifier) and publishing progress publisher")
			pub2?.send(completion: .finished)
		}
	}
}

extension TheDelegate: URLSessionDataDelegate {
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		Self.queue.addOperationAndWaitUntilFinished {
			self.dataPublishers[dataTask]?.send(data)
		}
	}
}

extension TheDelegate: URLSessionDownloadDelegate {
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		log.verbose("Got a download task to location: \(location)")
	}
}
