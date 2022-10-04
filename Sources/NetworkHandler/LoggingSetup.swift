import Foundation
import Swiftwood

fileprivate let setupLock = NSLock()
fileprivate var loggingIsSetup = false

typealias log = Swiftwood

func setupLogging() {
	setupLock.lock()
	defer { setupLock.unlock() }
	guard loggingIsSetup == false else { return }
	loggingIsSetup = true

	let consoleDestination = ConsoleLogDestination(maxBytesDisplayed: -1)
	consoleDestination.minimumLogLevel = .verbose
	log.appendDestination(consoleDestination, replicationOption: .forfeitToAlike)
}
