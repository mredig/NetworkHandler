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
	private var _demoModels = [DemoModel]()

	private(set) var demoModels: [DemoModel] {
		get {
			return _demoModels
		}

		set {
			_demoModels = newValue.sorted { $0.title < $1.title }
		}
	}

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

		let request = getURL.request
		NetworkHandler.default.transferMahCodableDatas(with: request) { [weak self] (result: Result<[String: DemoModel], NetworkError>) in
			do {
				let results = try result.get()
				self?.demoModels = Array(results.values)
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

	// MARK: - demo purposes

	func generateDemoData(completion: @escaping () -> Void) {
		DispatchQueue.global().async {
			// confirm latest information
			let semaphore = DispatchSemaphore(value: 0)
			self.fetchDemoModels { _ in
				semaphore.signal()
			}
			semaphore.wait()

			let baseURL = URL(string: "https://placekitten.com/")!

			while self.demoModels.count < 100 {
				let kittenURL = baseURL
					.appendingPathComponent("\(Int.random(in: 400...800))")
					.appendingPathComponent("\(Int.random(in: 400...800))")

				self.create(modelWithTitle: DemoText.demoNames.randomElement()!, andSubtitle: DemoText.demoSubtitles.randomElement()!, imageURL: kittenURL)
				print(self.demoModels.count)
			}
			completion()
		}

	}
}
