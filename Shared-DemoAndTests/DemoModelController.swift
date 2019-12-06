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

	@discardableResult func create(modelWithTitle title: String,
								   andSubtitle subtitle: String,
								   imageURL: URL,
								   completion: @escaping (NetworkError?) -> Void = { _ in }) -> DemoModel {
		let model = DemoModel(title: title, subtitle: subtitle, imageURL: imageURL)
		demoModels.append(model)
		put(model: model) { (result: Result<DemoModel, NetworkError>) in
			do {
				_ = try result.get()
				completion(nil)
			} catch {
				NSLog("There was an error creating the new model on the server: \(error)")
				completion(error as? NetworkError ?? NetworkError.otherError(error: error))
			}
		}
		return model
	}

	@discardableResult func update(model: DemoModel,
								   withTitle title: String,
								   subtitle: String,
								   imageURL: URL,
								   completion: @escaping (NetworkError?) -> Void = { _ in }) -> DemoModel? {
		guard let index = demoModels.firstIndex(of: model) else { return nil }
		var updatedModel = demoModels[index]
		updatedModel.title = title
		updatedModel.subtitle = subtitle
		updatedModel.imageURL = imageURL
		demoModels[index] = updatedModel
		put(model: updatedModel) { (result: Result<DemoModel, NetworkError>) in
			do {
				_ = try result.get()
				completion(nil)
			} catch {
				NSLog("There was an error updating the model on the server: \(error)")
				completion(error as? NetworkError ?? NetworkError.otherError(error: error))
			}
		}
		return updatedModel
	}

	func delete(model: DemoModel, completion: @escaping (NetworkError?) -> Void = { _ in }) {
		guard let index = demoModels.firstIndex(of: model) else { return }
		demoModels.remove(at: index)
		deleteFromServer(model: model) { (result: Result<Data?, NetworkError>) in
			do {
				_ = try result.get()
				completion(nil)
			} catch {
				NSLog("There was an error deleting the model on the server: \(error)")
				completion(error as? NetworkError ?? NetworkError.otherError(error: error))
			}
		}
	}

	func clearLocalModelCache() {
		demoModels.removeAll()
	}

	// MARK: - networking

	let baseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!

	func fetchDemoModels(completion: @escaping (NetworkError?) -> Void = { _ in }) {
		let getURL = baseURL.appendingPathExtension("json")

		let request = getURL.request
		NetworkHandler.default.transferMahCodableDatas(with: request) { [weak self] (result: Result<[String: DemoModel], NetworkError>) in
			do {
				let results = try result.get()
				self?.demoModels = Array(results.values)
				completion(nil)
			} catch NetworkError.dataWasNull {
				self?.demoModels.removeAll()
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
		request.httpMethod = .put

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
		request.httpMethod = .delete

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
				let dimensions = Int.random(in: 400...800)
				let kittenURL = baseURL
					.appendingPathComponent("\(dimensions)")
					.appendingPathComponent("\(dimensions)")

				self.create(modelWithTitle: DemoText.demoNames.randomElement()!, andSubtitle: DemoText.demoSubtitles.randomElement()!, imageURL: kittenURL)
				print(self.demoModels.count)
			}
			completion()
		}

	}
}
