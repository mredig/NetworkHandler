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
