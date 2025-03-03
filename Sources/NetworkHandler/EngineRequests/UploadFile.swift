import NetworkHalpers
import Foundation

public enum UploadFile: Hashable, Sendable {
	case localFile(URL)
	case data(Data)
	case streamProvider(UploadEngineRequest.StreamProvider)
}
