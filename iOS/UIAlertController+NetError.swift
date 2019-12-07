//
//  ErrorAlertController.swift
//
//  Created by Michael Redig on 5/9/19.
//  Copyright © 2019 Michael Redig. All rights reserved.
//
// swiftlint:disable function_body_length

import UIKit

public extension UIAlertController {
	private struct Message: Decodable {
		let message: String
	}

	// MARK: - Init
	convenience init(error: Error, preferredStyle: UIAlertController.Style = .alert) {
		self.init(title: nil, message: nil, preferredStyle: preferredStyle)
		configureWith(error: error)
	}

	// MARK: - Methods
	private func configureWith(error: Error) {
		title = "Error"

		if let error = error as? NetworkError {
			switch error {
			case .badData:
				message = "Bad Data"
			case .httpNon200StatusCode(let code, let data):
				let httpErrorMessage = getStatusCodeSpecifics(statusCode: code, potentialData: data)
				message = "HTTP transfer error: \(httpErrorMessage)"
			case .dataCodingError(specifically: let specificDecodeError, _):
				message = "There was an error decoding data. Please screenshot this and inform the developer: \(specificDecodeError)"
			case .imageDecodeError:
				message = "There was an error decoding a fetched image."
			case .noStatusCodeResponse:
				message = "The server did not provide a status code. If this persists, please inform the developer."
			case .otherError(let otherError):
				message = "There was an unexpected error. Please screenshot this and inform the developer: \(otherError)"
			case .urlInvalid(let stringURL):
				var info = ""
				if let unwrapped = stringURL {
					info = "'\(unwrapped)'"
				}
				message = "An invalid request was attempted. \(info)"
			case .databaseFailure(let otherError):
				message = "There was an error handling the local cache. Please screenshot and inform the developer: \(otherError)"
			case .dataWasNull:
				message = "There was no data returned from the server. This may or may not be expected."
			case .unspecifiedError(let reason):
				if let reason = reason {
					message = "There was an error: \(reason)"
				} else {
					message = "There was an unspecified error."
				}
			case .graphQLError(let error):
				let codesUntyped = [error.extensions.code, error.extensions.exception.code as Any, error.extensions.exception.errno as Any] as [Any]
				let codes: [String] = codesUntyped.compactMap {
					if let value = $0 as? String {
						return value
					} else if let value = $0 as? Int {
						return "\(value)"
					} else {
						return nil
					}
				}
				message = "There was an error: (\(codes)) - \(error.message)"
			}
		} else {
			message = "There was an unexpected error. Please screenshot this and inform the developer: \(error)"
		}

		if actions.isEmpty {
			let action = UIAlertAction(title: "Drat", style: .default)
			addAction(action)
		}
	}

	private func getStatusCodeSpecifics(statusCode: Int, potentialData data: Data? = nil) -> String {
		if let data = data {
			let decoder = JSONDecoder()
			if let message = try? decoder.decode(Message.self, from: data) {
				return message.message
			}
		}
		switch statusCode {
		case 300:
			return "The data source has moved. Please notify the developer."
		case 301:
			return "The data source has moved permanently. Please notify the developer."
		case 400:
			return "The data request was malformed. Please notify the developer"
		case 401:
			return "Access unauthorized. Please use correct credentials."
		case 403:
			return "Access forbidden to data. Please notify the developer."
		case 404:
			return "Data resource not found. This might be temporary. If issue persists, please notify the developer."
		case 410:
			return "Data resource has permanently been removed. This may be the end of this app. Feel free to notify the developer if they are still in business."
		case 500...504:
			return "Server is experiencing errors. It is likely worth trying again later. If issue persists, please notify the developer and inform them of this HTTP error code: \(statusCode)."
		default:
			return "There was an error retrieving data from the server. If this issue persists, please inform the developer and give them this HTTP error code: \(statusCode)"
		}
	}
}
