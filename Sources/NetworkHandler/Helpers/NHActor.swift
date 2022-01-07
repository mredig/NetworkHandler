import Foundation

@globalActor
struct NHActor: GlobalActor {
	actor ActorType {}

	static var shared = ActorType()
}
