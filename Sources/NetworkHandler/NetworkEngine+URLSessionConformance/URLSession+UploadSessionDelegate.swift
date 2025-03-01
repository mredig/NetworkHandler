import Foundation
import SwiftPizzaSnips

extension URLSession {
	class UploadDellowFelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
		private struct State {
			let progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation
			let bodyContinuation: ResponseBodyStream.Continuation

			let task: URLSessionUploadTask

			var lastUpdate = Date.distantPast

			let stream: InputStream

			unowned let parent: UploadDellowFelegate

			@NHActor
			var waitingContinuations: [CheckedContinuation<Void, Error>] = []

			enum Completion {
				case inProgress
				case finished
				case error(Error)
			}

			var dataSendCompletion: Completion = .inProgress

			init(
				progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation,
				bodyContinuation: ResponseBodyStream.Continuation,
				task: URLSessionUploadTask,
				stream: InputStream,
				parent: UploadDellowFelegate
			) {
				self.progressContinuation = progressContinuation
				self.bodyContinuation = bodyContinuation
				self.task = task
				self.stream = stream
				self.parent = parent
			}
		}

		private var states: [URLSessionTask: State] = [:]
		private let lock = MutexLock()

		func addTaskWith(
			stream: InputStream,
			progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation,
			bodyContinuation: ResponseBodyStream.Continuation,
			task: URLSessionUploadTask
		) {
			let state = State(progressContinuation: progressContinuation, bodyContinuation: bodyContinuation, task: task, stream: stream, parent: self)
			lock.withLock {
				states[task] = state
			}
		}

		func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
			lock.lock()
			guard let state = states[dataTask] else { return lock.unlock() }
			lock.unlock()

			_ = try? state.bodyContinuation.yield(Array(data))
		}

		func urlSession(
			_ session: URLSession,
			dataTask: URLSessionDataTask,
			didReceive response: URLResponse
		) async -> URLSession.ResponseDisposition {
			guard
				let state = lock.withLock({ () -> State? in
					guard let state = states[dataTask] else { return nil }
					return state
				})
			else { return .allow }

			Task { @NHActor in
				guard dataTask === state.task else { return }
				guard case .inProgress = state.dataSendCompletion else {
					fatalError("Multiple continuation completions")
				}

				lock.withLock {
					states[dataTask]?.dataSendCompletion = .finished
				}
			}

			return .allow
		}

		func urlSession(
			_ session: URLSession,
			task: URLSessionTask,
			needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
		) {
			var stream: InputStream?
			defer { completionHandler(stream) }
			lock.lock()
			defer { lock.unlock() }
			guard let state = states[task] else { return }
			stream = state.stream
		}

		func urlSession(
			_ session: URLSession,
			task: URLSessionTask,
			didSendBodyData bytesSent: Int64,
			totalBytesSent: Int64,
			totalBytesExpectedToSend: Int64
		) {
			lock.lock()
			guard let state = states[task] else { return lock.unlock() }
			lock.unlock()

			let now = Date.now
			guard
				task === state.task,
				now.timeIntervalSince(state.lastUpdate) > 0.0333333
			else { return }
			defer {
				lock.withLock {
					states[task]?.lastUpdate = now
				}
			}
			state.progressContinuation.yield(totalBytesSent)

			guard
				totalBytesExpectedToSend != NSURLSessionTransferSizeUnknown,
				totalBytesSent == totalBytesExpectedToSend
			else { return }
			state.progressContinuation.finish()
		}

		func urlSession(
			_ session: URLSession,
			task: URLSessionTask,
			didCompleteWithError error: (any Error)?
		) {
			lock.lock()
			guard let state = states[task] else {
				lock.unlock()
				return
			}
			states[task] = nil
			lock.unlock()

			state.progressContinuation.finish()
			try? state.bodyContinuation.finish(throwing: error)
		}
	}
}
