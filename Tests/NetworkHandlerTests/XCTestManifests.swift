import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
	[
		testCase(NetworkHandlerTests.allTests),
	]
}
#endif
