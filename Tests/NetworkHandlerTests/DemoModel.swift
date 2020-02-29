//
//  CodableStruct.swift
//  NetworkHandlerTests
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

struct DemoModel: Codable, Equatable {
	let id: UUID
	var title: String
	var subtitle: String
	var imageURL: URL

	init(id: UUID = UUID(), title: String, subtitle: String, imageURL: URL) {
		self.id	= id
		self.title = title
		self.subtitle = subtitle
		self.imageURL = imageURL
	}
}
