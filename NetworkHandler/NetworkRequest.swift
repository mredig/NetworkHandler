//
//  NetworkRequest.swift
//  NetworkHandler-iOS
//
//  Created by Michael Redig on 12/6/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

/// Pre-typed strings for use with NetworkRequest.httpMethod (or URLRequest.httpMethod)
public enum HTTPMethod: String {
	case post = "POST"
	case put = "PUT"
	case delete = "DELETE"
	case get = "GET"
	case head = "HEAD"
	case patch = "PATCH"
	case options = "OPTIONS"
}

public struct NetworkRequest {

	// MARK: - New Properties
	public private(set) var urlRequest: URLRequest
	public var expectedResponseCodes: Set<Int>

	// MARK: - Upgraded Properties
	public var httpMethod: HTTPMethod? {
		get { HTTPMethod(rawValue: urlRequest.httpMethod ?? "") }
		set { urlRequest.httpMethod = newValue?.rawValue }
	}

	// MARK: - Mirrored Properties
	public var cachePolicy: URLRequest.CachePolicy {
		get { urlRequest.cachePolicy }
		set { urlRequest.cachePolicy = newValue }
	}

	public var url: URL? {
		get { urlRequest.url }
		set { urlRequest.url = newValue }
	}
	public var httpBody: Data? {
		get { urlRequest.httpBody }
		set { urlRequest.httpBody = newValue }
	}
	public var httpBodyStream: InputStream? {
		get { urlRequest.httpBodyStream }
		set { urlRequest.httpBodyStream = newValue }
	}
	public var mainDocumentURL: URL? {
		get { urlRequest.mainDocumentURL }
		set { urlRequest.mainDocumentURL = newValue }
	}

	public var allHeaderFields: [String: String]? {
		get { urlRequest.allHTTPHeaderFields }
		set { urlRequest.allHTTPHeaderFields = newValue }
	}

	public var timeoutInterval: TimeInterval {
		get { urlRequest.timeoutInterval }
		set { urlRequest.timeoutInterval = newValue }
	}
	public var httpShouldHandleCookies: Bool {
		get { urlRequest.httpShouldHandleCookies }
		set { urlRequest.httpShouldHandleCookies = newValue }
	}
	public var httpShouldUsePipelining: Bool {
		get { urlRequest.httpShouldUsePipelining }
		set { urlRequest.httpShouldUsePipelining = newValue }
	}
	public var allowsCellularAccess: Bool {
		get { urlRequest.allowsCellularAccess }
		set { urlRequest.allowsCellularAccess = newValue }
	}

	public var networkServiceType: URLRequest.NetworkServiceType {
		get { urlRequest.networkServiceType }
		set { urlRequest.networkServiceType = newValue }
	}

	@available(iOS 13.0, OSX 10.15, *)
	public var allowsExpensiveNetworkAccess: Bool {
		get { urlRequest.allowsExpensiveNetworkAccess }
		set { urlRequest.allowsExpensiveNetworkAccess = newValue }
	}
	@available(iOS 13.0, OSX 10.15, *)
	public var allowsConstrainedNetworkAccess: Bool {
		get { urlRequest.allowsConstrainedNetworkAccess }
		set { urlRequest.allowsConstrainedNetworkAccess = newValue }
	}

	// MARK: - Lifecycle
	init(_ request: URLRequest, expectedResponseCodes: Set<Int> = [200]) {
		self.urlRequest = request
		self.expectedResponseCodes = expectedResponseCodes
	}

	// MARK: - Methods
	public mutating func addValue(_ value: HTTPHeaderValue, forHTTPHeaderField key: HTTPHeaderKey) {
		let strKey = getKeyString(from: key)
		let strValue = getValueString(from: value)

		urlRequest.addValue(strValue, forHTTPHeaderField: strKey)
	}

	public mutating func setValue(_ value: HTTPHeaderValue?, forHTTPHeaderField key: HTTPHeaderKey) {
		let strKey = getKeyString(from: key)

		guard let value = value else {
			urlRequest.setValue(nil, forHTTPHeaderField: strKey)
			return
		}
		let strValue = getValueString(from: value)
		urlRequest.setValue(strValue, forHTTPHeaderField: strKey)
	}

	public func value(forHTTPHeaderField key: HTTPHeaderKey) -> String? {
		let strKey = getKeyString(from: key)
		return urlRequest.value(forHTTPHeaderField: strKey)
	}

	// MARK: - Utility
	private func getKeyString(from key: HTTPHeaderKey) -> String {
		let strKey: String
		switch key {
		case .other(let otherKey):
			strKey = otherKey
		case .commonKey(let commonKey):
			strKey = commonKey.rawValue
		}
		return strKey
	}

	private func getValueString(from value: HTTPHeaderValue) -> String {
		let strValue: String
		switch value {
		case .contentType(let type):
			strValue = type.rawValue
		case .other(let otherValue):
			strValue = otherValue
		}
		return strValue
	}
}

extension Set: ExpressibleByIntegerLiteral where Element: FixedWidthInteger {

	public init(integerLiteral value: Int) {
		self.init()
		self.insert(Element(value))
	}

	public mutating func insert(_ array: [Element]) {
		Set(array).forEach { insert($0) }
	}

	public mutating func insertRange(_ range: ClosedRange<Element>) {
		Set(range).forEach { insert($0) }
	}
}
