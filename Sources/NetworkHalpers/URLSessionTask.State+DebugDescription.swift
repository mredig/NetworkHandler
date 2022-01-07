import Foundation
#if os(Linux)
import FoundationNetworking
#endif

extension URLSessionTask.State: CustomDebugStringConvertible {
	public var debugDescription: String {
		var out = ["URLSessionTask", "State"]
		switch self {
		case .suspended:
			out.append("suspended")
		case .canceling:
			out.append("cancelling")
		case .completed:
			out.append("completed")
		case .running:
			out.append("running")
		@unknown default:
			out.append("unknown")
		}
		return out.joined(separator: ".")
	}
}
