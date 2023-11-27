import Foundation
#if !os(Linux)
import Swizzles

extension URLSessionTask {
	private static let setState = NSSelectorFromString("setState:")
	typealias SetStateBlock = @convention(c) (AnyObject, Selector, URLSessionTask.State) -> Void

	private static let originalSetState: SetStateBlock = unsafeBitCast(swizzleSetState, to: SetStateBlock.self)

	static let swizzleSetState: IMP = {
		guard
			let method = class_getInstanceMethod(URLSessionTask.self, #selector(swizzled_setState))
		else { fatalError("Error fetching method") }
		let imp = method_getImplementation(method)

		return pspdf_swizzleSelector(URLSessionTask.self, URLSessionTask.setState, imp)
	}()

	@objc func swizzled_setState(_ newValue: URLSessionTask.State) {
		let oldValue = state

		Self.originalSetState(self, Self.setState, newValue)

		if
			newValue != oldValue,
			let del = delegate as? NetworkHandlerTransferDelegate {

			del.networkHandlerTask(self, stateChanged: newValue)
		}
	}
}
#endif
