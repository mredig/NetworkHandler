import Foundation
import Crypto

class NetworkDiskCache: CustomDebugStringConvertible {
	let fileManager = FileManager.default

	private(set) var size: UInt64 = 0

	var capacity: UInt64 {
		didSet {
			cacheQueue.addOperation { [weak self] in
				guard let self = self else { return }
				self.enforceCapacity()
			}
		}
	}

	let cacheName: String

	private(set) var count: Int = 0

	lazy private var cacheLocation = getCacheURL()

	private let cacheQueue: OperationQueue = {
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	var isActive: Bool {
		cacheQueue.operationCount != 0
	}

	init(capacity: UInt64 = .max, cacheName: String? = nil) {
		self.capacity = capacity
		self.cacheName = cacheName ?? "NetworkDiskCache"

		cacheQueue.addOperation { [weak self] in
			self?.refreshSize()
			self?.enforceCapacity()
		}
	}

	// MARK: - CRUD
	func setData(_ getData: @autoclosure @escaping () -> Data?, key: String, sync: Bool = false) {
		let operation = BlockOperation { [self] in
			guard let data = getData() else {
				NSLog("Error getting data to save for key: \(key)")
				return
			}

			let fileLocation = path(for: key)
			let oldFileSize = fileSize(at: fileLocation)

			do {
				try data.write(to: fileLocation)
				subtractSize(oldFileSize ?? 0, removingFile: false)
				addSize(for: data)
				updateAccessDate(fileLocation)
			} catch {
				NSLog("Error saving cache data: \(error)")
			}
		}

		cacheQueue.addOperations([operation], waitUntilFinished: sync)
	}


	func getData(for key: String) -> Data? {
		let filePath = path(for: key)
		var data: Data?
		let operation = BlockOperation { [self] in
			guard let loadedData = try? Data(contentsOf: filePath) else { return }
			data = loadedData
			updateAccessDate(filePath)
		}

		cacheQueue.addOperations([operation], waitUntilFinished: true)
		return data
	}

	func deleteData(for key: String) {
		let filePath = path(for: key)
		deleteFile(at: filePath)
	}

	func deleteFile(at path: URL) {
		guard fileManager.fileExists(atPath: path.path) else { return }

		let oldSize = fileSize(at: path) ?? 0
		do {
			try fileManager.removeItem(at: path)
			subtractSize(oldSize, removingFile: true)
		} catch {
			NSLog("Error removing \(path): \(error)")
		}
	}

	func resetCache() {
		let resetOp = BlockOperation { [self] in
			do {
				let contents = try fileManager.contentsOfDirectory(at: cacheLocation, includingPropertiesForKeys: [], options: [])

				for file in contents {
					deleteFile(at: file)
				}
			} catch {
				NSLog("Error resetting cache: \(error)")
			}
		}

		cacheQueue.addOperations([resetOp], waitUntilFinished: true)
	}

	// MARK: - Utility
	private func getCacheURL() -> URL {
		do {
			let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			let cacheResource = cacheDir.appendingPathComponent(cacheName)

			if !fileManager.fileExists(atPath: cacheResource.path) {
				try fileManager.createDirectory(at: cacheResource, withIntermediateDirectories: true, attributes: nil)
			}
			return cacheResource
		} catch {
			fatalError("Error retrieving cache directory: \(error)")
		}
	}

	private func path(for key: String) -> URL {
		let sha1 = Insecure.SHA1.hash(data: Data(key.utf8)).toHexString()
		return cacheLocation.appendingPathComponent(sha1)
	}

	private func updateAccessDate(_ url: URL) {
		let now = Date()
		do {
			try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
		} catch {
			NSLog("Error updating access time: \(error)")
		}
	}

	private func fileSize(at url: URL) -> UInt64? {
		guard
			let sizeValue = try? url.resourceValues(forKeys: [.fileSizeKey]),
			let size = sizeValue.fileSize
		else { return nil }

		return .init(size)
	}

	private func addSize(for data: Data) {
		let size = UInt64(data.count)
		addSize(size)
	}

	private func addSize(for url: URL) {
		guard let size = fileSize(at: url) else { return }
		addSize(size)
	}

	private func addSize(_ value: UInt64) {
		size += value
		count += 1
		cacheQueue.addOperation { [self] in
			enforceCapacity()
		}
	}

	private func subtractSize(for url: URL) {
		guard let size = fileSize(at: url) else { return }
		subtractSize(size, removingFile: true)
	}

	private func subtractSize(_ value: UInt64, removingFile: Bool) {
		if removingFile { count -= 1 }
		size -= value
	}

	private func enforceCapacity() {
		guard size > capacity else { return }

		do {
			let contents = try fileManager.contentsOfDirectory(at: cacheLocation, includingPropertiesForKeys: [.contentModificationDateKey], options: [])

			let sorted = try contents.sorted { a, b in
				let dateInfoA = try a.resourceValues(forKeys: [.contentModificationDateKey])
				let dateInfoB = try b.resourceValues(forKeys: [.contentModificationDateKey])

				guard
					let dateA = dateInfoA.contentModificationDate,
					let dateB = dateInfoB.contentModificationDate
				else { return false }
				return dateA < dateB
			}

			var oldestFirst = sorted.makeIterator()
			while let oldestOnDisk = oldestFirst.next() {
				guard size > capacity else { return }

				deleteFile(at: oldestOnDisk)
			}
		} catch {
			NSLog("Error enforcing disk cache capacity: \(error)")
		}
	}

	private func refreshSize() {
		do {
			let contents = try fileManager.contentsOfDirectory(at: cacheLocation, includingPropertiesForKeys: [.fileSizeKey], options: [])
			size = try contents.reduce(0, {
				let fileSizeValues = try $1.resourceValues(forKeys: [.fileSizeKey])
				guard let fileSize = fileSizeValues.fileSize else { return $0 }

				return $0 + UInt64(fileSize)
			})
			count = contents.count
		} catch {
			NSLog("Error calculating disk cache size: \(error)")
		}
	}

	var debugDescription: String {
		"Network Disk Cache: \(cacheLocation)"
	}
}
