//
//  File.swift
//  
//
//  Created by Michael Redig on 7/26/20.
//

import Foundation

/// most easily populated by setting up env vars in xcode scheme. not sure how to do on linux...
enum TestEnvironment {
	static let s3AccessKey = ProcessInfo.processInfo.environment[.s3AccessKeyKey] ?? ""
	static let s3AccessSecret = ProcessInfo.processInfo.environment[.s3AccessSecretKey] ?? ""
}

fileprivate extension String {
	static let s3AccessKeyKey = "S3KEY"
	static let s3AccessSecretKey = "S3SECRET"
}
