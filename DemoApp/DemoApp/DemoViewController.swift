//
//  DemoViewController.swift
//  Demo
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit
import NetworkHandler

class DemoViewController: UITableViewController {

	// MARK: - Properties
	let demoModelController = DemoModelController()
	private var tasks = [UITableViewCell: Task<Void, Error>]()

	// MARK: - Outlets
	@IBOutlet private var generateDemoDataButton: UIButton!

	// MARK: - Actions
	@IBAction func generateDemoDataButtonPressed(_ sender: UIButton) {
		sender.isEnabled = false
//		demoModelController.generateDemoData { [weak self] in
//			self?.demoModelController.fetchDemoModels(completion: { [weak self] error in
//				if let error = error {
//					NSLog("There was an error \(error)")
//				}
//				DispatchQueue.main.async {
//					self?.tableView.reloadData()
//					sender.isEnabled = true
//				}
//			})
//		}
		Task {
			do {
				try await demoModelController.generateDemoData()
			} catch {
				print("Error generating data: \(error)")
			}
			refreshData()
			sender.isEnabled = true
		}
	}

	@objc func refreshData() {
		Task {
			do {
				try await demoModelController.fetchDemoModels()
			} catch {
				let alertVC = UIAlertController(title: "Error", message: "Error loading data: \(error)", preferredStyle: .alert)

				let button = UIAlertAction(title: "Okay", style: .default, handler: nil)

				alertVC.addAction(button)

				present(alertVC, animated: true)
			}

			tableView.refreshControl?.endRefreshing()
			tableView.reloadData()
		}
	}

	// MARK: - VC Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.refreshControl = UIRefreshControl()
		tableView.refreshControl?.addTarget(self, action: #selector(refreshData), for: .valueChanged)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshData()
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let dest = segue.destination as? CreateViewController {
			dest.demoModelController = demoModelController
		}
	}
}

// MARK: tableview stuff
extension DemoViewController {
	// MARK: - Tableview
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		demoModelController.demoModels.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

		let demoModel = demoModelController.demoModels[indexPath.row]
		cell.textLabel?.text = demoModel.title
		cell.detailTextLabel?.text = demoModel.subtitle
		cell.imageView?.image = nil
		loadImage(for: cell, at: indexPath)
		return cell
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let demoModel = demoModelController.demoModels[indexPath.row]
			Task {
				try await demoModelController.delete(model: demoModel)
				tableView.deleteRows(at: [indexPath], with: .automatic)
			}
		}
	}

	// MARK: - Methods
	func loadImage(for cell: UITableViewCell, at indexPath: IndexPath) {
		tasks[cell]?.cancel()
		tasks[cell] = nil

		let demoModel = demoModelController.demoModels[indexPath.row]

		tasks[cell] = Task {
			do {
				let (data, _) = try await NetworkHandler.default.transferMahDatas(
					for: demoModel.imageURL.request,
					delegate: nil,
					usingCache: true,
					sessionConfiguration: nil)

				try Task.checkCancellation()
				cell.imageView?.image = UIImage(data: data)
				cell.layoutSubviews()
				tasks[cell] = nil
			} catch {
				if case NetworkError.otherError(error: let otherError) = error {
					if (otherError as NSError).code == -999 {
						// cancelled
						return
					}
				}
				print("Error loading image from url: '\(demoModel.imageURL)': \(error)")
			}


		}
//		tasks[cell] = NetworkHandler.default.transferMahDatas(
//			with: demoModel.imageURL.request,
//			usingCache: true,
//			completion: { [weak self] (result: Result<Data, Error>) in
//				DispatchQueue.main.async {
//					do {
//						let imageData = try result.get()
//						cell.imageView?.image = UIImage(data: imageData)
//						cell.layoutSubviews()
//						self?.tasks[cell] = nil
//					} catch {
//						if case NetworkError.otherError(error: let otherError) = error {
//							if (otherError as NSError).code == -999 {
//								// cancelled
//								return
//							}
//						}
//						NSLog("error loading image from url '\(demoModel.imageURL)': \(error)")
//					}
//				}
//			})
	}
}
