//
//  NetworkMockingSession.swift
//  NetworkHandler
//
//  Created by Michael Redig on 6/17/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

struct NetworkMockingSession: NetworkLoader {

	let mockData: Data?
	let mockError: Error?
	let mockResponseCode: Int
	var mockDelay: TimeInterval

	init(mockData: Data?, mockError: Error?, mockResponseCode: Int = 200, mockDelay: TimeInterval = 0.1) {
		self.mockData = mockData
		self.mockError = mockError
		self.mockResponseCode = mockResponseCode
		self.mockDelay = mockDelay
	}

	func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask? {
		guard let url = request.url else { completion(nil, nil, nil); return nil }
		let mockResponse = HTTPURLResponse(url: url, statusCode: mockResponseCode, httpVersion: "HTTP/2", headerFields: nil)

		DispatchQueue.global().asyncAfter(deadline: .now() + mockDelay) {
			completion(self.mockData, mockResponse, self.mockError)
		}

		return nil
	}


}
