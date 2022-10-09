import Foundation
@_exported import NetworkHalpers
#if os(Linux)
import FoundationNetworking
#endif

/**
 assists in version 2 uploads
 */
internal class UploadDelegate: NSObject, URLSessionTaskDelegate {
	weak var delegate: NetworkHandlerTransferDelegate?

	private(set) weak var task: URLSessionTask?

	private var stateObserver: NSKeyValueObservation?
	static private let queue: OperationQueue = {
		let q = OperationQueue()
		q.maxConcurrentOperationCount = 1
		return q
	}()

	let dataPublisher = NHPublisher<Data, Error>()
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

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error {
			dataPublisher.send(completion: .failure(error))
		} else {
			dataPublisher.send(completion: .finished)
		}
	}

	func setTask(_ task: URLSessionTask) {
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

extension UploadDelegate: URLSessionDataDelegate {
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		Self.queue.addOperationAndWaitUntilFinished {
			self.dataPublisher.send(data)
		}
	}
}
