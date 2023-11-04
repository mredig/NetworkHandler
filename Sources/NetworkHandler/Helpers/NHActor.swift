import Foundation

@globalActor
public struct NHActor: GlobalActor {
	public actor ActorType {}

	public static var shared = ActorType()
}
