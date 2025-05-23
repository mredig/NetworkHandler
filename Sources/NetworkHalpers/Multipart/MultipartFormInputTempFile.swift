import Foundation
import SwiftPizzaSnips

/**
Use this to generate a binary file to upload multipart form data. This copies source data and files into a single
blob prior to uploading a file, so be aware of this behavior. Be sure to use a `URLSessionConfig.background` instance
to get proper progress reporting (for some reason? This is just from some minimal personal testing, but has been
semi consistent in my experience).
*/
public class MultipartFormInputTempFile: @unchecked Sendable {

	public let boundary: String
	private let originalBoundary: String

	private var parts: [Part] = []

	private let lock = MutexLock()

	public var multipartContentTypeHeaderValue: HTTPHeaders.Header.Value {
		"multipart/form-data; boundary=\(boundary)"
	}

	public init(boundary: String = UUID().uuidString) {
		self.originalBoundary = boundary
		self.boundary = "Boundary-\(boundary)"
	}

	public func addPart(named name: String, string: String) {
		let part = Part(name: name, boundary: boundary, content: .data(Data(string.utf8)))
		addPart(part)
	}

	public func addPart(
		named name: String,
		data: Data,
		filename: String? = nil,
		contentType: String = "application/octet-stream"
	) {
		let part = Part(
			name: name,
			boundary: boundary,
			filename: filename,
			contentType: contentType,
			content: .data(data))
		addPart(part)
	}

	public func addPart(
		named name: String,
		fileURL: URL,
		filename: String? = nil,
		contentType: String
	) {
		let part = Part(
			name: name,
			boundary: boundary,
			filename: filename,
			contentType: contentType,
			content: .localURL(fileURL))
		addPart(part)
	}

	private func addPart(_ part: Part) {
		lock.withLock {
			parts.append(part)
		}
	}

	// swiftlint:disable:next cyclomatic_complexity
	public func renderToFile() throws -> URL {
		let tempDir = FileManager
			.default
			.temporaryDirectory
			.appendingPathComponent("multipartUploads")
		try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

		let multipartTempFile = tempDir
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("tmp")

		//		let filehandle = FileHandle(forWritingTo: multipartTempFile)
		let fileHandle = OutputStream(url: multipartTempFile, append: true)
		fileHandle?.open()

		let bufferSize = 1024 // KB
		* 1024 // MB
		* 25 // count of MB
		let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferSize)
		buffer.initialize(repeating: 0)

		guard
			let pointer = buffer.baseAddress
		else { throw MultipartError.cannotInitializeBufferPointer }

		let parts = lock.withLock { self.parts }

		for part in parts {
			for (index, byte) in part.headers.enumerated() {
				buffer[index] = byte
			}
			let headerBytesWritten = fileHandle?.write(pointer, maxLength: part.headers.count)
			guard headerBytesWritten == part.headers.count else { throw MultipartError.headerWritingNotCompleted }

			let inputStream: InputStream?
			switch part.content {
			case .localURL(let url):
				guard let inStream = InputStream(url: url) else { throw MultipartError.cannotOpenInputFile }
				inputStream = inStream
			case .data(let data):
				inputStream = InputStream(data: data)
			default: inputStream = nil
			}

			if let inputStream = inputStream {
				inputStream.open()
				while inputStream.hasBytesAvailable {
					let inputBytes = inputStream.read(pointer, maxLength: bufferSize)
					guard inputBytes >= 0 else { throw MultipartError.cannotReadInputFile }
					guard inputBytes > 0 else { break }
					fileHandle?.write(pointer, maxLength: inputBytes)
				}
			}

			for (index, byte) in part.footer.enumerated() {
				buffer[index] = byte
			}
			let footerBytesWritten = fileHandle?.write(pointer, maxLength: part.footer.count)
			guard footerBytesWritten == part.footer.count else { throw MultipartError.footerWritingNotCompleted }
		}

		let formFooter = Data("--\(boundary)--\r\n".utf8)
		for (index, byte) in formFooter.enumerated() {
			buffer[index] = byte
		}
		let footerBytesWritten = fileHandle?.write(pointer, maxLength: formFooter.count)
		guard footerBytesWritten == formFooter.count else { throw MultipartError.footerWritingNotCompleted }

		return multipartTempFile
	}

	public func renderToFile() async throws -> URL {
		let task = Task.detached(priority: .utility) {
			try self.renderToFile()
		}
		return try await task.value
	}

	enum MultipartError: CustomDebugStringConvertible, Sendable, LocalizedError {
		case streamNotPart
		case cannotInitializeBufferPointer
		case headerWritingNotCompleted
		case footerWritingNotCompleted
		case cannotOpenInputFile
		case cannotReadInputFile

		var debugDescription: String {
			switch self {
			case .streamNotPart: return "streamNotPart"
			case .cannotInitializeBufferPointer: return "cannotInitializeBufferPointer"
			case .headerWritingNotCompleted: return "headerWritingNotCompleted"
			case .footerWritingNotCompleted: return "footerWritingNotCompleted"
			case .cannotOpenInputFile: return "cannotOpenInputFile"
			case .cannotReadInputFile: return "cannotReadInputFile"
			}
		}

		public var errorDescription: String? { debugDescription }

		public var failureReason: String? { debugDescription }

		public var helpAnchor: String? { debugDescription }

		public var recoverySuggestion: String? { debugDescription }
	}
}
