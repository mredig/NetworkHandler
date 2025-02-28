import Foundation

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
			var waitingContinuations: [CheckedContinuation<HTTPURLResponse, Error>] = []

			enum Completion {
				case inProgress
				case finished(HTTPURLResponse)
				case error(Error)
			}
			@NHActor
			var dataSendCompletion: Completion = .inProgress {
				didSet {
					switch dataSendCompletion {
					case .inProgress:
						return
					case .finished, .error:
						parent.triggerUploadContinuations(for: self)
					}
				}
			}

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



		private let lock = NSLock()

		//		init(
		//			stream: InputStream,
		//			progressContinuation: AsyncThrowingStream<Int64, Error>.Continuation,
		//			bodyContinuation: ResponseBodyStream.Continuation,
		//			task: URLSessionUploadTask
		//		) {
		//			self.stream = stream
		//			self.progressContinuation = progressContinuation
		//			self.bodyContinuation = bodyContinuation
		//			self.task = task
		//			let state = State(
		//				progressContinuation: progressContinuation,
		//				bodyContinuation: bodyContinuation,
		//				task: task,
		//				stream: stream)
		//		}

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

		deinit {
			print("gonzo!")
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

				guard
					let response = state.task.response as? HTTPURLResponse
				else {
					throw UploadError.noServerResponseHeader
				}

				lock.withLock {
					states[dataTask]?.dataSendCompletion = .finished(response)
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
		}

		func urlSession(
			_ session: URLSession,
			task: URLSessionTask,
			didCompleteWithError error: (any Error)?
		) {
			lock.lock()
			guard let state = states[task] else { return lock.unlock() }
			lock.unlock()

			try? state.bodyContinuation.finish(throwing: error)
			Task { @NHActor in
				triggerUploadContinuations(for: state)
			}
		}

		@NHActor
		private func triggerUploadContinuations(for state: State) {
			let result: Result<HTTPURLResponse, Error>
			switch state.dataSendCompletion {
			case .inProgress:
				return
			case .finished(let response):
				result = .success(response)
				state.progressContinuation.finish()
			case .error(let error):
				result = .failure(error)
				state.progressContinuation.finish()
			}

			for continuation in state.waitingContinuations {
				continuation.resume(with: result)
			}
			lock.withLock {
				states[state.task]?.waitingContinuations = []
			}
		}

		@NHActor
		func waitForUploadCompletion(of task: URLSessionTask) async throws -> HTTPURLResponse {
			guard
				let state = lock.withLock({ () -> State? in
					guard let state = states[task] else { return nil }
					return state
				})
			else { throw UploadError.notTrackingRequestedTask }

			if task.state == .suspended {
				task.resume()
			}
			switch state.dataSendCompletion {
			case .inProgress:
				return try await withCheckedThrowingContinuation { continuation in
					lock.withLock {
						states[task]?.waitingContinuations.append(continuation)
					}
				}
			case .finished(let response):
				return response
			case .error(let error):
				throw error
			}
		}
	}
}

