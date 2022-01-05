import Foundation

/// most easily populated by setting up env vars in xcode scheme. not sure how to do on linux...
public enum TestEnvironment {
	public static let s3AccessKey = ProcessInfo.processInfo.environment[.s3AccessKeyKey] ?? ""
	public static let s3AccessSecret = ProcessInfo.processInfo.environment[.s3AccessSecretKey] ?? ""
}

fileprivate extension String {
	static let s3AccessKeyKey = "S3KEY"
	static let s3AccessSecretKey = "S3SECRET"
}
