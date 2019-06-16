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
	let demoModelController = DemoModelController()

	private var tasks = [UITableViewCell: URLSessionDataTask]()

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		demoModelController.fetchDemoModels { [weak self] (error) in
			DispatchQueue.main.async {
				if let error = error {
					let alert = UIAlertController(error: error)
					self?.present(alert, animated: true)
				}
				self?.tableView.reloadData()
			}
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let dest = segue.destination as? CreateViewController {
			dest.demoModelController = demoModelController
		}
	}
}

// MARK: tableview stuff
extension DemoViewController {
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return demoModelController.demoModels.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

		let demoModel = demoModelController.demoModels[indexPath.row]
		cell.textLabel?.text = demoModel.title
		cell.detailTextLabel?.text = demoModel.subtitle
		loadImage(for: cell, at: indexPath)
		return cell
	}

	func loadImage(for cell: UITableViewCell, at indexPath: IndexPath) {
		tasks[cell]?.cancel()
		tasks[cell] = nil

		let demoModel = demoModelController.demoModels[indexPath.row]

		tasks[cell] = NetworkHandler.default.transferMahDatas(with: demoModel.imageURL.request, usingCache: true, completion: { [weak self] (result: Result<Data, NetworkError>) in
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
