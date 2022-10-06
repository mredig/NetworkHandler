import Foundation
@testable import NetworkHandler

class DownloadDelegate: NetworkHandlerTransferDelegate {
	var task: URLSessionTask?

	let taskPub = NHPublisher<URLSessionTask, Never>()
	let progressPub = NHPublisher<Double, Never>()
	let statePub = NHPublisher<URLSessionTask.State, Never>()

	func networkHandlerTaskDidStart(_ task: URLSessionTask) {
		taskPub.send(task)
	}

	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double) {
		progressPub.send(progress)
	}

	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State) {
		statePub.send(state)
	}
}
