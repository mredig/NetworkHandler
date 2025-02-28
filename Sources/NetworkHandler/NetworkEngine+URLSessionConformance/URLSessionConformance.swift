import NetworkHalpers
import Foundation
import SwiftPizzaSnips

extension URLSession: NetworkEngine {
	public func fetchNetworkData(from request: DownloadEngineRequest) async throws -> (EngineResponseHeader, ResponseBodyStream) {
		let urlRequest = request.urlRequest
		let (dlBytes, response) = try await bytes(for: urlRequest)

		let engResponse = EngineResponseHeader(from: response as! HTTPURLResponse)
		let (stream, continuation) = ResponseBodyStream.makeStream()

		let byteGobbler = Task {
			do {
				var buffer: [UInt8] = []
				buffer.reserveCapacity(1024)
				for try await byte in dlBytes {
					buffer.append(byte)

					guard buffer.count == 1024 else { continue }
					try continuation.yield(buffer)
					buffer.removeAll(keepingCapacity: true)
				}
				if buffer.isOccupied {
					try continuation.yield(buffer)
				}
				try continuation.finish()
			} catch {
				try continuation.finish(throwing: error)
			}
		}

		continuation.onTermination = { reason in
			let proceed: Bool
			switch reason {
			case .cancelled: proceed = true
			case .finished(let error):
				proceed = error != nil
			}
			guard proceed else { return }
			dlBytes.task.cancel()
			byteGobbler.cancel()
		}

		return (engResponse, stream)
	}

	public enum UploadError: Error {
		case noServerResponseHeader
		case noInputStream
		case notTrackingRequestedTask
	}
}
