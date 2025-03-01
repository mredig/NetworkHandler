import AsyncHTTPClient
import Swift

extension HTTPClient: NetworkEngine {
	public func fetchNetworkData(
		from request: DownloadEngineRequest
	) async throws -> (EngineResponseHeader, ResponseBodyStream) {
		let httpClientRequest = request.httpClientRequest

		let httpClientResponse = try await execute(httpClientRequest, deadline: .distantFuture)

		let (bodyStream, bodyContinuation) = ResponseBodyStream.makeStream()

		let bodyTask = _Concurrency.Task {
			do {
				for try await chunk in httpClientResponse.body {
					let bytes = Array(chunk.readableBytesView)
					try bodyContinuation.yield(bytes)
				}
			} catch {
				try bodyContinuation.finish(throwing: error)
			}
			try bodyContinuation.finish()
		}

		bodyContinuation.onTermination = { reason in
			switch reason {
			case .cancelled:
				bodyTask.cancel()
			case .finished(let error):
				if error != nil {
					bodyTask.cancel()
				}
			}
		}

		let engineResponse = EngineResponseHeader(from: httpClientResponse, with: request.url)
		return (engineResponse, bodyStream)
	}
	
	public func uploadNetworkData(
		request: UploadEngineRequest,
		with payload: UploadEngineRequest.UploadFile
	) async throws -> (
		uploadProgress: AsyncThrowingStream<Int64, any Error>,
		response: _Concurrency.Task<EngineResponseHeader, any Error>,
		responseBody: ResponseBodyStream
	) {
		fatalError()
	}
	
	public func shutdown() {
		shutdown { error in
			if let error {
				print("Error shutting down client: \(error)")
			}
		}
	}
}
