import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLSessionTask.State: @retroactive CustomDebugStringConvertible {
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
