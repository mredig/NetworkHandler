import Foundation

internal extension OperationQueue {
	@discardableResult func addOperationAndWaitUntilFinished<T>(_ block: @escaping () -> T) -> T {
		var output: T!
		let operation = BlockOperation(block: {
			output = block()
		})
		addOperations([operation], waitUntilFinished: true)
		return output
	}
}
