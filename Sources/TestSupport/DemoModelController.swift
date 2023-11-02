import Foundation
import NetworkHandler

public class DemoModelController {
	private var _demoModels = [DemoModel]()

	private(set) var demoModels: [DemoModel] {
		get {
			_demoModels
		}
		set {
			_demoModels = newValue.sorted { $0.title < $1.title }
		}
	}

	public init() {}

	@discardableResult public func create(
		modelWithTitle title: String,
		andSubtitle subtitle: String,
		imageURL: URL,
		completion: @escaping (Error?) -> Void = { _ in }) -> DemoModel {
			let model = DemoModel(title: title, subtitle: subtitle, imageURL: imageURL)
			demoModels.append(model)
			Task {
				do {
					_ = try await put(model: model)
					completion(nil)
				} catch {
					completion(error)
				}
			}
			return model
		}

	@discardableResult public func update(
		model: DemoModel,
		withTitle title: String,
		subtitle: String,
		imageURL: URL,
		completion: @escaping (Error?) -> Void = { _ in }) -> DemoModel? {
			guard let index = demoModels.firstIndex(of: model) else { return nil }
			var updatedModel = demoModels[index]
			updatedModel.title = title
			updatedModel.subtitle = subtitle
			updatedModel.imageURL = imageURL
			demoModels[index] = updatedModel

			Task { [updatedModel] in
				do {
					_ = try await put(model: updatedModel)
					completion(nil)
				} catch {
					completion(error)
				}
			}
			return updatedModel
		}

	public func delete(model: DemoModel) async throws {
		guard let index = demoModels.firstIndex(of: model) else { return }
		demoModels.remove(at: index)
		try await deleteFromServer(model: model)
	}

	public func clearLocalModelCache() {
		demoModels.removeAll()
	}

	// MARK: - networking

	let baseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!

	public func fetchDemoModels() async throws {
		let getURL = baseURL.appendingPathExtension("json")

		let request = getURL.request

		do {
			let stuff: [DemoModel] = try await NetworkHandler.default.transferMahCodableDatas(for: request).decoded
			self.demoModels = stuff
		} catch {
			throw error
		}
	}

	public func put(model: DemoModel) async throws -> DemoModel {
		let putURL = baseURL
			.appendingPathComponent(model.id.uuidString)
			.appendingPathExtension("json")

		var request = putURL.request
		request.httpMethod = .put

		try request.encodeData(model)

		return try await NetworkHandler.default.transferMahCodableDatas(for: request).decoded
	}

	public func deleteFromServer(model: DemoModel) async throws {
		let deleteURL = baseURL
			.appendingPathComponent(model.id.uuidString)
			.appendingPathExtension("json")

		var request = deleteURL.request
		request.httpMethod = .delete

		try await NetworkHandler.default.transferMahDatas(for: request)
	}

	// MARK: - demo purposes

	public func generateDemoData() async throws {

		try await fetchDemoModels()

		let baseURL = URL(string: "https://placekitten.com/")!

		while self.demoModels.count < 100 {
			let dimensions = Int.random(in: 400...800)
			let kittenURL = baseURL
				.appendingPathComponent("\(dimensions)")
				.appendingPathComponent("\(dimensions)")

			create(
				modelWithTitle: DemoText.demoNames.randomElement()!,
				andSubtitle: DemoText.demoSubtitles.randomElement()!,
				imageURL: kittenURL)
			print(self.demoModels.count)
		}
	}
}
