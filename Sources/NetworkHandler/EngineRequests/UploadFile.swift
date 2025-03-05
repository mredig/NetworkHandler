import NetworkHalpers
import Foundation
import SwiftPizzaSnips

public enum UploadFile: Hashable, Sendable, Withable {
	case localFile(URL)
	case data(Data)
	case streamProvider(UploadEngineRequest.StreamProvider)
}
