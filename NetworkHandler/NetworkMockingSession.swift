//
//  NetworkMockingSession.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/17/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

public struct NetworkMockingSession: NetworkLoader {
	// MARK: - Properties
	public let mockData: Data?
	public let mockError: Error?
	public let mockResponseCode: Int
	public var mockDelay: TimeInterval
	public var httpVersion = "HTTP/2"

	public typealias ServerSideSimulationHandler = (URLRequest) -> (Data?, Int, Error?)
	let serverSideSimulatorHandler: ServerSideSimulationHandler?

	// MARK: - Init
	public init(mockData: Data?, mockError: Error?, mockResponseCode: Int = 200, mockDelay: TimeInterval = 0.1) {
		self.mockData = mockData
		self.mockError = mockError
		self.mockResponseCode = mockResponseCode
		self.mockDelay = mockDelay
		self.serverSideSimulatorHandler = nil
	}

	/// Using the `serverSideSimulatorHandler` closure, you can confirm that the input you are providing is correct for
	/// the request you're making, then provide response data, code, and error as the return value varying to the input
	/// Effectively, this lets you simulate what's happening server side, if desired.
	public init(mockDelay: TimeInterval = 0.1, serverSideSimulatorHandler: @escaping ServerSideSimulationHandler) {
		self.serverSideSimulatorHandler = serverSideSimulatorHandler
		self.mockData = nil
		self.mockError = nil
		self.mockResponseCode = -1
		self.mockDelay = mockDelay
	}

	// MARK: - Public
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask? {
		guard let url = request.url else { completion(nil, nil, nil); return nil }
		let mockResponse: HTTPURLResponse?
		let returnData: Data?
		let returnError: Error?
		if let handler = serverSideSimulatorHandler {
			let (verificationData, verificationResponse, verificationError) = handler(request)
			mockResponse = HTTPURLResponse(url: url, statusCode: verificationResponse, httpVersion: httpVersion, headerFields: nil)
			returnData = verificationData
			returnError = verificationError
		} else {
			mockResponse = HTTPURLResponse(url: url, statusCode: mockResponseCode, httpVersion: httpVersion, headerFields: nil)
			returnData = mockData
			returnError = mockError
		}

		DispatchQueue.global().asyncAfter(deadline: .now() + mockDelay) {
			completion(returnData, mockResponse, returnError)
		}

		return nil
	}
}
