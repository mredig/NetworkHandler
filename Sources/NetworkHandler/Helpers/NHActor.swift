import Foundation

@globalActor
public struct NHActor: GlobalActor {
	public actor ActorType {}

	nonisolated(unsafe)
	public static var shared = ActorType()
}
