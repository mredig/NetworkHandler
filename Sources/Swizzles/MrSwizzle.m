#import "include/MrSwizzle.h"
#import <objc/Runtime.h>
#import <objc/Message.h>

IMP pspdf_swizzleSelector(Class clazz, SEL selector, IMP newImplementation) {
	// If the method does not exist for this class, do nothing.
	const Method method = class_getInstanceMethod(clazz, selector);
	if (!method) {
		NSLog(@"%@ doesn't exist in %@.", NSStringFromSelector(selector), NSStringFromClass(clazz));
		// Cannot swizzle methods that are not implemented by the class or one of its parents.
		return NULL;
	}

	// Make sure the class implements the method. If this is not the case, inject an implementation, only calling 'super'.
	const char *types = method_getTypeEncoding(method);
	class_addMethod(clazz, selector, imp_implementationWithBlock(^(__unsafe_unretained id self, va_list argp) {
		struct objc_super super = {self, clazz};
		return ((id(*)(struct objc_super *, SEL, va_list))objc_msgSendSuper)(&super, selector, argp);
	}), types);

	// Swizzling.
	return class_replaceMethod(clazz, selector, newImplementation, types);
}
