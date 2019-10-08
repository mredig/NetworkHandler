//
//  CreateViewController.swift
//  Demo
//
//  Created by Michael Redig on 6/15/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

class CreateViewController: UIViewController {

	// MARK: - Properties
	var demoModelController: DemoModelController?

	// MARK: - Outlets
	@IBOutlet var titleTextField: UITextField!
	@IBOutlet var subtitleTextField: UITextField!
	@IBOutlet var widthTextField: UITextField!
	@IBOutlet var heightTextField: UITextField!

	// MARK: - Actions
	@IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
		guard let title = titleTextField.text, !title.isEmpty,
			let subtitle = subtitleTextField.text, !subtitle.isEmpty,
			let width = Int(widthTextField.text ?? ""),
			let height = Int(heightTextField.text ?? "") else { return }

		let baseURL = URL(string: "https://placekitten.com/")!
		let kittenURL = baseURL
			.appendingPathComponent("\(width)")
			.appendingPathComponent("\(height)")

		demoModelController?.create(modelWithTitle: title, andSubtitle: subtitle, imageURL: kittenURL)
		navigationController?.popViewController(animated: true)
	}
}
