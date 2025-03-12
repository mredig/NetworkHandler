import Foundation
import Logging
import Crypto
import SwiftPizzaSnips
import NetworkHalpers

class NetworkDiskCache: CustomDebugStringConvertible, @unchecked Sendable {
	let fileManager = FileManager.default

	private(set) var size: UInt64 = 0

	var capacity: UInt64 {
		didSet {
			enforceCapacity()
		}
	}

	let cacheName: String

	private(set) var count: Int = 0

	lazy private var cacheLocation = getCacheURL()

	static private let cacheLock = MutexLock()
	static private func lockCache() {
		cacheLock.lock()
		_isActive = true
	}
	static private func unlockCache() {
		_isActive = false
		cacheLock.unlock()
	}
	static private func withLock<T, F>(_ block: () throws(F) -> T) throws(F) -> T {
		lockCache()
		defer { unlockCache() }
		return try block()
	}

	nonisolated(unsafe)
	static private var _isActive = false

	let logger: Logger

	var isActive: Bool {
		Self._isActive
	}

	init(capacity: UInt64 = .max, cacheName: String? = nil, logger: Logger) {
		self.logger = logger
		self.capacity = capacity
		self.cacheName = cacheName ?? "NetworkDiskCache"

		refreshSize()
		enforceCapacity()
	}

	// MARK: - CRUD
	func setData(_ getData: @autoclosure @escaping @Sendable () -> Data?, key: String, sync: Bool = false) {
		@Sendable func doIt() {
			Self.withLock {
				_setData(getData(), key: key)
			}
		}

		if sync {
			doIt()
		} else {
			Task {
				doIt()
			}
		}
	}

	private func _setData(_ getData: @autoclosure @escaping () -> Data?, key: String) {
		guard let data = getData() else {
			logger.error("Error getting data to save for key", metadata: ["Key": "\(key)"])
			return
		}

		let fileLocation = path(for: key)
		let oldFileSize = _fileSize(at: fileLocation)

		do {
			try data.write(to: fileLocation)
			_subtractSize(oldFileSize ?? 0, removingFile: false)
			_addSize(for: data)
			_updateAccessDate(fileLocation)
			logger.debug("Saved cached file", metadata: ["Key": "\(key)"])
		} catch {
			logger.error("Error saving cache data:", metadata: ["Error": "\(error)"])
		}
	}

	func getData(for key: String) -> Data? {
		Self.withLock {
			_getData(for: key)
		}
	}

	private func _getData(for key: String) -> Data? {
		let filePath = path(for: key)

		guard let loadedData = try? Data(contentsOf: filePath) else { return nil }
		_updateAccessDate(filePath)

		logger.debug("Cache hit", metadata: ["Key": "\(key)"])
		return loadedData
	}

	func deleteData(for key: String) {
		Self.withLock {
			let filePath = path(for: key)
			_deleteFile(at: filePath)
		}
	}

	private func _deleteFile(at path: URL) {
		guard fileManager.fileExists(atPath: path.path) else { return }

		let oldSize = _fileSize(at: path) ?? 0
		do {
			try fileManager.removeItem(at: path)
			_subtractSize(oldSize, removingFile: true)
			logger.debug("Deleted cached file", metadata: ["File": "\(path.path(percentEncoded: false))"])
		} catch {
			logger.error("Error removing \(path):", metadata: ["Error": "\(error)"])
		}
	}

	func resetCache() {
		Self.lockCache()
		defer { Self.unlockCache() }

		guard cacheLocation.checkResourceIsAccessible() else { return }
		do {
			try fileManager.removeItem(at: cacheLocation)
			refreshSize()
			logger.info("Reset disk cache", metadata: ["Name": "\(cacheName)"])
		} catch {
			logger.error("Error resetting disk cache by clearing folder. Trying individual files.", metadata: ["Error": "\(error)"])
			do {
				let contents = try fileManager.contentsOfDirectory(at: cacheLocation, includingPropertiesForKeys: [], options: [])

				for file in contents {
					_deleteFile(at: file)
				}
				logger.info("Reset disk cache", metadata: ["Name": "\(cacheName)"])
			} catch {
				logger.error("Error resetting cache:", metadata: ["Error": "\(error)"])
			}
		}
	}

	// MARK: - Utility
	private func getCacheURL() -> URL {
		Self.lockCache()
		defer { Self.unlockCache() }
		do {
			let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			let cacheResource = cacheDir.appendingPathComponent(cacheName)

			if cacheResource.checkResourceIsAccessible() == false {
				try fileManager.createDirectory(at: cacheResource, withIntermediateDirectories: true)
			}
			return cacheResource
		} catch {
			fatalError("Error retrieving cache directory: \(error)")
		}
	}

	private func path(for key: String) -> URL {
		let sha1 = Insecure.SHA1.hash(data: Data(key.utf8)).hex()
		if cacheLocation.checkResourceIsAccessible() == false {
			try? fileManager.createDirectory(at: cacheLocation, withIntermediateDirectories: true)
		}
		return cacheLocation.appendingPathComponent(sha1)
	}

	private func _updateAccessDate(_ url: URL) {
		let now = Date()
		do {
			try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
			logger.trace("Updated disk cache access date", metadata: ["Path": "\(url.path(percentEncoded: false))"])
		} catch {
			logger.error("Error updating access time:", metadata: ["Error": "\(error)"])
		}
	}

	private func _fileSize(at url: URL) -> UInt64? {
		guard
			let sizeValue = try? url.resourceValues(forKeys: [.fileSizeKey]),
			let size = sizeValue.fileSize
		else { return nil }

		return .init(size)
	}

	private func _addSize(for data: Data) {
		let size = UInt64(data.count)
		_addSize(size)
	}

	private func _addSize(_ value: UInt64) {
		size += value
		count += 1
		_enforceCapacity()
	}

	private func _subtractSize(_ value: UInt64, removingFile: Bool) {
		if removingFile { count -= 1 }
		guard value < size else {
			size = 0
			return
		}
		size -= value
	}

	private func enforceCapacity() {
		Self.lockCache()
		defer { Self.unlockCache() }
		_enforceCapacity()
	}

	private func _enforceCapacity() {
		guard size > capacity else { return }

		do {
			let contents = try fileManager
				.contentsOfDirectory(
					at: cacheLocation,
					includingPropertiesForKeys: [.contentModificationDateKey],
					options: [])

			let sorted = try contents.sorted { a, b in // swiftlint:disable:this identifier_name
				let dateInfoA = try a.resourceValues(forKeys: [.contentModificationDateKey])
				let dateInfoB = try b.resourceValues(forKeys: [.contentModificationDateKey])

				guard
					let dateA = dateInfoA.contentModificationDate,
					let dateB = dateInfoB.contentModificationDate
				else { return false }
				return dateA < dateB
			}

			logger.trace("Enforcing disk capacity...")
			var oldestFirst = sorted.makeIterator()
			while let oldestOnDisk = oldestFirst.next() {
				guard size > capacity else { return }
				
				_deleteFile(at: oldestOnDisk)
			}
			logger.trace("Done enforcing disk capacity")
		} catch {
			logger.error("Error enforcing disk cache capacity:", metadata: ["Error": "\(error)"])
		}
	}

	private func refreshSize() {
		guard cacheLocation.checkResourceIsAccessible() else {
			size = 0
			count = 0
			return
		}
		do {
			let contents = try fileManager
				.contentsOfDirectory(
					at: cacheLocation,
					includingPropertiesForKeys: [.fileSizeKey],
					options: [])
			size = try contents.reduce(0, {
				let fileSizeValues = try $1.resourceValues(forKeys: [.fileSizeKey])
				guard let fileSize = fileSizeValues.fileSize else { return $0 }

				return $0 + UInt64(fileSize)
			})
			count = contents.count
			logger.trace("Refreshed disk cache size", metadata: ["Size": "\(size)", "Count": "\(count)"])
		} catch {
			logger.error("Error calculating disk cache size:", metadata: ["Error": "\(error)"])
		}
	}

	var debugDescription: String {
		"Network Disk Cache: \(cacheLocation)"
	}
}
