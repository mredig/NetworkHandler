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
	private var tasks = [UITableViewCell: NetworkLoadingTask]()

	// MARK: - Outlets
	@IBOutlet private var generateDemoDataButton: UIButton!

	// MARK: - Actions
	@IBAction func generateDemoDataButtonPressed(_ sender: UIButton) {
		sender.isEnabled = false
		demoModelController.generateDemoData { [weak self] in
			self?.demoModelController.fetchDemoModels(completion: { [weak self] error in
				if let error = error {
					NSLog("There was an error \(error)")
				}
				DispatchQueue.main.async {
					self?.tableView.reloadData()
					sender.isEnabled = true
				}
			})
		}
	}

	@objc func refreshData() {
		tableView.refreshControl?.beginRefreshing()
		demoModelController.fetchDemoModels { [weak self] error in
			DispatchQueue.main.async {
				if let error = error {
					let alert = UIAlertController(error: error)
					self?.present(alert, animated: true)
				}
				self?.tableView.refreshControl?.endRefreshing()
				self?.tableView.reloadData()
			}
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
			demoModelController.delete(model: demoModel)
			tableView.deleteRows(at: [indexPath], with: .automatic)
		}
	}

	// MARK: - Methods
	func loadImage(for cell: UITableViewCell, at indexPath: IndexPath) {
		tasks[cell]?.cancel()
		tasks[cell] = nil

		let demoModel = demoModelController.demoModels[indexPath.row]

		tasks[cell] = NetworkHandler.default.transferMahDatas(with: demoModel.imageURL.request,
															  usingCache: true,
															  completion: { [weak self] (result: Result<Data, NetworkError>) in
			DispatchQueue.main.async {
				do {
					let imageData = try result.get()
					cell.imageView?.image = UIImage(data: imageData)
					cell.layoutSubviews()
					self?.tasks[cell] = nil
				} catch {
					NSLog("error loading image from url '\(demoModel.imageURL)': \(error)")
				}
			}
		})
	}
}
