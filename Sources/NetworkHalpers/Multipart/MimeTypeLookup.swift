import Foundation

enum MimeTypeLookup {
	struct Mime: RawRepresentable, Hashable {
		let rawValue: String
	}

	struct Extension: RawRepresentable, Hashable {
		let rawValue: String
	}

	static private var extensionMap: [Extension: Mime] = [:]

	static private func loadTypes() {
		guard
			extensionMap.count == 0
		else { return }

		let sourceURLs: [URL] = [
			URL(fileURLWithPath: "/etc/mime.types"),
			URL(fileURLWithPath: "/etc/apache2/mime.types"),
			URL(fileURLWithPath: "~/.mime.types")
		]

		let sourceData: [String] = sourceURLs
			.compactMap { (url: URL) -> String? in
				do {
					return try String(contentsOf: url)
				} catch where (error as NSError).code == 260 {
					// not found
					return nil
				} catch {
					print("Error loading mime types at location: \(url)!: \(error)")
					return nil
				}
			}

		let linesWithStrippedComments = sourceData
			.flatMap { (line: String) -> [String] in
				let lines = line
					.split(separator: "\n")
					.map { String($0) }
					.filter { $0.hasPrefix("#") == false }
				return lines
			}

		func addToExtensionMap(extension ext: Extension, mimeType: Mime) {
			extensionMap[ext] = mimeType
		}

		for line in linesWithStrippedComments {

			var parts = line
				.replacingOccurrences(of: ##"\s+"##, with: " ", options: .regularExpression, range: nil)
				.split(separator: " ")
				.map(String.init)

			let mimeString = parts.removeFirst()
			let mime = Mime(rawValue: mimeString)

			let extensions = parts
				.map(Extension.init(rawValue:))

			extensions.forEach {
				addToExtensionMap(extension: $0, mimeType: mime)
			}
		}
	}

	static func mimeType(for fileExtension: String) -> String {
		Self.loadTypes()

		return extensionMap[Extension(rawValue: fileExtension)]?.rawValue ?? "application/octet-stream"
	}
}
