#ifndef MrSwizzle_h
#define MrSwizzle_h

#import <Foundation/Foundation.h>

/**
 Reference the following example provided (loaned from this project, so defer to the actual project for more up to date code). This is to swizzle the default method of the
 `state` property to notify the delegate that the state has updated.

 ```
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
 ```

 Heavily "borrowed" from [Peter Steinberger](https://pspdfkit.com/blog/2019/swizzling-in-swift/) (hence the pspdf reference remaining for homage)
 */
IMP pspdf_swizzleSelector(Class clazz, SEL selector, IMP newImplementation);

#endif /* MrSwizzle_h */
