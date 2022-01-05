#if os(macOS)
import AppKit

extension NSImage {
	func pngData() -> Data? {
		guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
		let newRep = NSBitmapImageRep(cgImage: cgImage)
		newRep.size = size

		return newRep.representation(using: .png, properties: [:])
	}
}
#endif
