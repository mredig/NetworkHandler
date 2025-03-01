import Foundation
import SwiftPizzaSnips

extension URLSession {
	/// Used internally for upload tasks. Requires being set as the delegate on the URLSession. I can't remember if it
	/// mattered if it was the task delegate or not, but that's how the current implementation works, so I'd suggest
	/// being consistent with that.
	class UploadDellowFelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
		/// Tracks the state of a single task. Stored in a dictionary in the delegate.
		private struct State {
			/// Relays the total number of bytes sent for a given task in a stream.
			let progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation
			/// Relays the data body chunk blobs received from the response.
			let bodyContinuation: ResponseBodyStream.Continuation

			/// The actual network task
			let task: URLSessionUploadTask

			/// Tracks the most recently progress continuation usage to keep from flooding the progress stream.
			var lastUpdate = Date.distantPast

			/// Source of the upload.
			let stream: InputStream

			/// Reference back to the delegate
			unowned let parent: UploadDellowFelegate

			enum Completion {
				case inProgress
				case finished
				case error(Error)
			}

			@NHActor
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

		/// Tracks all the tasks with their current state. Accessed only with `lock`. For more info, see `lock`
		private var states: [URLSessionTask: State] = [:]
		/// Lock for keeping thread safety. However, it's probably not necessary. The delegate is set to be used on a single queue, so it's probably uneeded overhead...
		/// That said, I don't fully know the mechanism for the delegate thread, so until I can trust it fully, I'm going to keep using this.
		private let lock = MutexLock()

		func addTaskWith(
			stream: InputStream,
		/// Adds a task for tracking with the delegate.
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
