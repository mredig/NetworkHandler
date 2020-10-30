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
	/// Only used internally for equality checks
	private let id = UUID()
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
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTaskEditor {
		return NetworkDataTask(mockDelay: mockDelay) {
			let tuple = synchronousLoadData(with: request)
			completion(tuple.0, tuple.1, tuple.2)
		}
	}

	public func synchronousLoadData(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
		guard let url = request.url else {
			return (nil, nil, nil)
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

		return (returnData, mockResponse, returnError)
	}
}

extension NetworkMockingSession: Hashable {
	/// the logic here is that, since closures CANNOT be compared for equality, we instead have to compare this parent
	/// object for equality. The closure itself is a constant of `NetworkMockingSession` and cannot be changed once created.
	/// Following that logic, other constant properties do not need to be compared apart from the ID. Since there are a
	/// couple mutable properties, those also have to be compared for equality, which means this method needs updating
	/// whenever variable properties change on this struct. The catch with this approach is that if two `NetworkMockingSession`s are created identically, they will not equate to each other, but instead will only equate `true` when comparing copies of the same original. This approach should work fine for the purpose of storing in a collection and checking to confirm uniqueness.
	public static func == (lhs: NetworkMockingSession, rhs: NetworkMockingSession) -> Bool {
		lhs.id == rhs.id &&
		lhs.mockDelay == rhs.mockDelay &&
		lhs.httpVersion == rhs.httpVersion
	}

	/// See documentation for `static ==` of `NetworkMockingSession` for logic behind this.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
		hasher.combine(mockDelay)
		hasher.combine(httpVersion)
	}
}

public class NetworkDataTask: NetworkLoadingTaskEditor {
	public var countOfBytesExpectedToReceive: Int64 = 0
	public var countOfBytesReceived: Int64 = 0
	public var countOfBytesExpectedToSend: Int64 = 0
	public var countOfBytesSent: Int64 = 0
	public var priority: Float = 0.5

	private var completionClosures: [NetworkLoadingClosure] = [] {
		didSet {
			runCompletion()
		}
	}

	public var result: Result<Data?, Error>?

	typealias ServerSideSimulationHandler = NetworkMockingSession.ServerSideSimulationHandler

	private static let queue = DispatchQueue(label: "finishedQueue")
	@NH.ThreadSafe(queue: NetworkDataTask.queue) private var _status: NetworkLoadingTaskStatus = .suspended
	public private(set) var status: NetworkLoadingTaskStatus {
		get { _status }
		set {
			_status = newValue
			runCompletion()
		}
	}

	private let simHandler: () -> Void

	public let mockDelay: TimeInterval

	init(mockDelay: TimeInterval, simHandler: @escaping () -> Void) {
		self.simHandler = simHandler
		self.mockDelay = mockDelay
	}

	private func runCompletion() {
		guard status == .completed else { return }
		completionClosures.forEach { $0(self) }
	}

	public func resume() {
		status = .running

		DispatchQueue.global().asyncAfter(deadline: .now() + mockDelay) {
			guard self.status == .running else { return }
			self.status = .completed
			self.simHandler()
		}
	}

	public func cancel() {
		status = .canceling
	}

	public func suspend() {
		status = .suspended
	}

	public func onUploadProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self { self }

	public func onDownloadProgressUpdated(_ perform: @escaping NetworkLoadingClosure) -> Self { self }

	public func onCompletion(_ perform: @escaping NetworkLoadingClosure) -> Self {
		completionClosures.append(perform)
		return self
	}
}
