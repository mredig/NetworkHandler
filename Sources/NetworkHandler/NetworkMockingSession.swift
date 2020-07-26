//
//  NetworkMockingSession.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/17/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public struct NetworkMockingSession: NetworkLoader {
	// MARK: - Properties
	/// The data returned by the mocking session. This value is superceded by the return value of `serverSideSimulatorHanler`, if set.
	public let mockData: Data?
	/// The error returned by the mocking session. Provide `nil` to simulate successful transactions.
	public let mockError: Error?
	/// The response code the mock session returns.
	public let mockResponseCode: Int?
	/// How many seconds the mock session should artificially delay before completing. Default is `0.1` seconds.
	public var mockDelay: TimeInterval
	public var httpVersion = "HTTP/2"

	public typealias ServerSideSimulationHandler = (URLRequest) -> (Data?, Int?, Error?)
	/// Allows you to simulate server side logic. Allows you to confirm you are sending consistent, valid data to the server.
	let serverSideSimulatorHandler: ServerSideSimulationHandler?

	// MARK: - Init
	public init(mockData: Data?, mockError: Error?, mockResponseCode: Int? = 200, mockDelay: TimeInterval = 0.1) {
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
		self.mockResponseCode = nil
		self.mockDelay = mockDelay
	}

	// MARK: - Public
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTask {
		guard let url = request.url else {
			return NetworkDataTask(mockDelay: mockDelay) {
				completion(nil, nil, nil)
			}
		}
		let responseCode: Int?
		let returnData: Data?
		let returnError: Error?
		if let handler = serverSideSimulatorHandler {
			let (verificationData, verificationResponse, verificationError) = handler(request)
			responseCode = verificationResponse
			returnData = verificationData
			returnError = verificationError
		} else {
			responseCode = mockResponseCode
			returnData = mockData
			returnError = mockError
		}
		// check response code and create appropriate HTTPURLResponse
		let mockResponse: HTTPURLResponse?
		if let responseCode = responseCode {
			mockResponse = HTTPURLResponse(url: url, statusCode: responseCode, httpVersion: httpVersion, headerFields: nil)
		} else {
			mockResponse = nil
		}

		return NetworkDataTask(mockDelay: mockDelay) {
			completion(returnData, mockResponse, returnError)
		}
	}
}

public class NetworkDataTask: NetworkLoadingTask {
	typealias ServerSideSimulationHandler = NetworkMockingSession.ServerSideSimulationHandler

	private let simHandler: () -> Void

	private let queue = DispatchQueue(label: "finishedQueue")
	private var _isResumed = false
	private(set) var isResumed: Bool {
		get {
			queue.sync { _isResumed }
		}
		set {
			queue.sync { _isResumed = newValue }
		}
	}
	private var _isFinished = false
	private var isFinished: Bool {
		get {
			queue.sync { _isFinished }
		}
		set {
			queue.sync { _isFinished = newValue }
		}
	}

	public let mockDelay: TimeInterval

	init(mockDelay: TimeInterval, simHandler: @escaping () -> Void) {
		self.simHandler = simHandler
		self.mockDelay = mockDelay
	}

	public func resume() {
		isResumed = true

		DispatchQueue.global().asyncAfter(deadline: .now() + mockDelay) {
			guard !self.isFinished, self.isResumed else { return }
			self.isFinished = true
			self.simHandler()
		}
	}

	public func cancel() {
		isResumed = false
	}

}
