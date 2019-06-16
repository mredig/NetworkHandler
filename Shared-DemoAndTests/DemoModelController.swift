//
//  DemoModelController.swift
//  NetworkHandlerTests
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import NetworkHandler

class DemoModelController {
	private(set) var demoModels = [DemoModel]()

	func create(modelWithTitle title: String, andSubtitle subtitle: String, imageURL: URL) {
		let model = DemoModel(title: title, subtitle: subtitle, imageURL: imageURL)
		demoModels.append(model)
		put(model: model) { (result: Result<DemoModel, NetworkError>) in
			do {
				_ = try result.get()
			} catch {
				NSLog("There was an error creating the new model on the server: \(error)")
			}
		}
	}

	func update(model: DemoModel, withTitle title: String, subtitle: String, imageURL: URL) {
		guard let index = demoModels.firstIndex(of: model) else { return }
		demoModels[index].title = title
		demoModels[index].subtitle = subtitle
		demoModels[index].imageURL = imageURL
		put(model: model) { (result: Result<DemoModel, NetworkError>) in
			do {
				_ = try result.get()
			} catch {
				NSLog("There was an error updating the model on the server: \(error)")
			}
		}
	}

	func delete(model: DemoModel) {
		guard let index = demoModels.firstIndex(of: model) else { return }
		demoModels.remove(at: index)
		deleteFromServer(model: model) { (result: Result<Data?, NetworkError>) in
			do {
				_ = try result.get()
			} catch {
				NSLog("There was an error deleting the model on the server: \(error)")
			}
		}
	}

	// MARK: - networking

	let baseURL = URL(string: "https://networkhanderltestbase.firebaseio.com/DemoAndTests")!

	func fetchDemoModels(completion: @escaping (NetworkError?) -> Void = { _ in }) {
		let getURL = baseURL.appendingPathExtension("json")

		NetworkHandler.default.transferMahCodableDatas(with: getURL.request) { [weak self] (result: Result<[String: DemoModel], NetworkError>) in
			do {
				let results = try result.get()
				self?.demoModels = Array(results.values).sorted { $0.title < $1.title }
				completion(nil)
			} catch {
				NSLog("Error loading demo models: \(error)")
				completion(error as? NetworkError ?? NetworkError.otherError(error: error))
			}
		}
	}

	func put(model: DemoModel, completion: @escaping (Result<DemoModel, NetworkError>) -> Void) {
		let putURL = baseURL
			.appendingPathComponent(model.id.uuidString)
			.appendingPathExtension("json")

		var request = putURL.request
		request.httpMethod = HTTPMethods.put.rawValue

		do {
			request.httpBody = try JSONEncoder().encode(model)
		} catch {
			completion(.failure(NetworkError.otherError(error: error)))
			return
		}

		NetworkHandler.default.transferMahCodableDatas(with: request, completion: completion)
	}

	func deleteFromServer(model: DemoModel, completion: @escaping (Result<Data?, NetworkError>) -> Void) {
		let deleteURL = baseURL
			.appendingPathComponent(model.id.uuidString)
			.appendingPathExtension("json")

		var request = deleteURL.request
		request.httpMethod = HTTPMethods.delete.rawValue

		NetworkHandler.default.transferMahOptionalDatas(with: request, completion: completion)
	}
}
