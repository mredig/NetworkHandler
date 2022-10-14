import XCTest
//@testable import KnowMeEngine
//@testable import KnowMeMockResources
@testable import NetworkHandler
import Swizzles


@MainActor
final class NHStressTests: XCTestCase {

//	override init() {
//		super.init()
//		print("started")
//	}

	override func setUp() {
		super.setUp()
		print("set up")

		URLSessionTask.swizzleMahNizzle
//		doThing()
	}

	override func tearDown() {
		super.tearDown()
		print("tear down")
	}

	@NHActor
	private func downloadTask(session: URLSession, request: NetworkRequest, delegate: OnTheDL?) async throws -> (Data, HTTPURLResponse) {
//		let (data, response) = try await session.data(for: request.urlRequest)
//
//		guard let httpResponse = response as? HTTPURLResponse else {
//			print("Error: Server replied with no status code")
//			throw NetworkError.noStatusCodeResponse
//		}
//
//		return (data, httpResponse)

		let (asyncBytes, response) = try await session.bytes(for: request.urlRequest, delegate: delegate)
		let task = asyncBytes.task
		task.priority = request.priority.rawValue
		delegate?.task = task

		guard let httpResponse = response as? HTTPURLResponse else {
			print("Error: Server replied with no status code")
			throw NetworkError.noStatusCodeResponse
		}

//		let stateObserver: NSKeyValueObservation?
		// yes, this could be a bit cleaner and just directly set the `stateObserver`, but this, for whatever reason,
		// causes a race condition crash to happen roughly 1 out of 200-1500 data fetches. this, while effectively being
		// the same thing, doesn't seem to do that.
		if let delegate {
			await MainActor.run {
				delegate.networkHandlerTaskDidStart(task)
//				delegate.networkHandlerTask(task, stateChanged: task.state)
			}

//			stateObserver = task.observe(\.state, options: [.new]) { task, _ in
//				Task { @MainActor in
//					delegate.networkHandlerTask(task, stateChanged: task.state)
//				}
//			}
		} else {
//			stateObserver = nil
		}
//		defer { stateObserver?.invalidate() }

		return try await withTaskCancellationHandler(operation: {
			var data = Data()
			data.reserveCapacity(Int(httpResponse.expectedContentLength))
			var lastUpdate = Date.distantPast
			var count = 0
			for try await byte in asyncBytes {
				data.append(byte)
				count += 1

				let now = Date()
				if now > lastUpdate.addingTimeInterval(1 / 30) {
					lastUpdate = now

					delegate?.networkHandlerTask(task, didProgress: Double(count) / Double(httpResponse.expectedContentLength))
				}
			}

			return (data, httpResponse)
//		}, onCancel: { [weak stateObserver, weak task] in
		}, onCancel: { [weak task] in
			task?.cancel()
//			stateObserver?.invalidate()
		})
	}

	func testStressingNetworkCallsAndDecodingManyTimes() async throws {
		for i in 1...99999 {
			print("starting iteration \(i)")
			_ = await Task {
				try await testStressingNetworkCallsAndDecoding()
			}.result

			print("stopping iteration \(i)")
		}
	}

	func testStressingNetworkCallsAndDecoding() async throws {
//		let networkController = try await signedInNetworkController(useLiveInternet: true)
//		let networkHandler = NetworkHandler(name: "testing")

		let decoder = JSONDecoder()

		let url = URL(string: "https://mredig-fileshare.s3.us-west-1.wasabisys.com/sample.json?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=T133H6EBRDX7CL0Z2P3M/20221012/us-east-1/s3/aws4_request&X-Amz-Date=20221012T230010Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=2efcddbeb13e92eb49afaf929ef2ee0ddb513c3a7772d6a62240c7be77c2bda4")!
//		let data: Data = try await networkController.genericNetworkingRequest(request: url.request)
//		let (data, _) = try await networkHandler.transferMahDatas(for: url.request)
		var request = url.request
		request.cachePolicy = .returnCacheDataDontLoad

		let delegate = OnTheDL()
		let (data, _) = try await downloadTask(session: .shared, request: request, delegate: delegate)

		let objects = try decoder.decode([Randos].self, from: data)

		print(objects.count)
	}

	func tetGenerateSomeJSON() throws {
		let objects = (0...50).map { _ in Randos() }

		let encoder = JSONEncoder()
		let data = try encoder.encode(objects)

		print(String(data: data, encoding: .utf8)!)
	}
	struct Randos: Codable {
		let someString: String
		let someInt: Int
		let abul: Bool
		let afloat: Double
		let aRay: [String]
		let dicktion: [Int: String]

		init() {
			let alpha = "abcdefghijklmnopqrstuvwxyz"
			let alphaNumsStr = alpha.uppercased() + alpha + " "
			let alphaNums = Set(alphaNumsStr)
			self.someString = (5...500).compactMap({ _ in String(alphaNums.randomElement()!) }).joined()
			self.someInt = Int.random(in: 5...5000000000)
			self.abul = Bool.random()
			self.afloat = Double.random(in: -50000000...(.greatestFiniteMagnitude))
			self.aRay = (1..<Int.random(in: 2...100)).map { _ in (16...64).compactMap({ _ in String(alphaNums.randomElement()!) }).joined() }
			self.dicktion = (1...Int.random(in: 1...100)).reduce(into: [:], {
				$0[$1] = (8...16).compactMap({ _ in String(alphaNums.randomElement()!) }).joined()
			})
		}
	}
}

class OnTheDL: NSObject, NetworkHandlerTransferDelegate, URLSessionTaskDelegate {
	var task: URLSessionTask?

	func networkHandlerTask(_ task: URLSessionTask, stateChanged state: URLSessionTask.State) {
		print("\(task.taskIdentifier) state changed to: \(state)")
	}

	func networkHandlerTaskDidStart(_ task: URLSessionTask) {
		print("Started")
	}

	func networkHandlerTask(_ task: URLSessionTask, didProgress progress: Double) {
		print("Progress: \(progress)")
	}

//	func tseatsdtasdf(cls: AnyClass, selector: Selector, newImp: IMP) {
//		guard
//			let method = class_getInstanceMethod(cls, selector)
//		else {
//			print("\(selector) doesn't exist in \(cls)")
//			return
//		}
//
//		let types = method_getTypeEncoding(method)
//
//		class_addMethod(cls, selector, imp_implementationWithBlock({ [unowned self] (argp: __darwin_va_list) in
//			let theSuper = objc_super(receiver: self, super_class: cls)
//		}), type)
//	}
}


//static _Nullable IMP pspdf_swizzleSelector(Class clazz, SEL selector, IMP newImplementation) {
//	// If the method does not exist for this class, do nothing.
//	const Method method = class_getInstanceMethod(clazz, selector);
//	if (!method) {
//		PSPDFLogError(@"%@ doesn't exist in %@.", NSStringFromSelector(selector), NSStringFromClass(clazz));
//		// Cannot swizzle methods that are not implemented by the class or one of its parents.
//		return NULL;
//	}
//
//	// Make sure the class implements the method. If this is not the case, inject an implementation, only calling 'super'.
//	const char *types = method_getTypeEncoding(method);
//	class_addMethod(clazz, selector, imp_implementationWithBlock(^(__unsafe_unretained id self, va_list argp) {
//		struct objc_super super = {self, clazz};
//		return ((id(*)(struct objc_super *, SEL, va_list))objc_msgSendSuper2)(&super, selector, argp);
//	}), types);
//
//	// Swizzling.
//	return class_replaceMethod(clazz, selector, newImplementation, types);
//}

extension URLSessionTask {
	static let swizzleMahNizzle: Void = {
//		let getState = NSSelectorFromString("state")
//		guard
//			let originalCurrentOpenURLMethod = class_getInstanceMethod(URLSessionTask.self, getState),
//			let swizzledCurrentOpenURLMethod = class_getInstanceMethod(URLSessionTask.self, #selector(swizzled_fart))
//		else { return }
//		method_exchangeImplementations(originalCurrentOpenURLMethod, swizzledCurrentOpenURLMethod)

		let setState = NSSelectorFromString("setState:")
		guard
			let originalCurrentOpenURLMethod = class_getInstanceMethod(URLSessionTask.self, setState),
			let swizzledCurrentOpenURLMethod = class_getInstanceMethod(URLSessionTask.self, #selector(swizzled_setState))
		else { return }
		method_exchangeImplementations(originalCurrentOpenURLMethod, swizzledCurrentOpenURLMethod)
//
//		guard
//			let originalDeprecatedOpenURLMethod = class_getInstanceMethod(UIApplication.self, #selector(openURL(_:))),
//			let swizzledDeprecatedOpenURLMethod = class_getInstanceMethod(UIApplication.self, #selector(swizzled_depOpenURL(_:)))
//		else { return }
//		method_exchangeImplementations(originalDeprecatedOpenURLMethod, swizzledDeprecatedOpenURLMethod)
//
//
//		guard
//			let originalCanOpenURLMethod = class_getInstanceMethod(UIApplication.self, #selector(canOpenURL(_:))),
//			let swizzledCanOpenURLMethod = class_getInstanceMethod(UIApplication.self, #selector(swizzled_canOpenURL(_:)))
//		else { return }
//		method_exchangeImplementations(originalCanOpenURLMethod, swizzledCanOpenURLMethod)
	}()

//	@objc func swizzled_openURL(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler completion: ((Bool) -> Void)? = nil) {
//		swizzled_openURL(url, options: options, completionHandler: completion)
//		log.verbose("opening \(url)")
//	}

	@objc func swizzled_depOpenURL(_ url: URL) {
		swizzled_depOpenURL(url)
		log.verbose("deprecated opening \(url)")
	}

	@objc func swizzled_canOpenURL(_ url: URL) {
		swizzled_canOpenURL(url)
		log.verbose("checking if can open \(url)")
	}

	@objc func swizzled_fart() -> URLSessionTask.State {
		let state = swizzled_fart()

		print("itsa swizzed!")
		return state
	}

	@objc func test(_ val: Int, didSomething something: String) {

	}

	@objc func swizzled_setState(_ newValue: URLSessionTask.State) {
		let oldValue = state
		swizzled_setState(newValue)

//		print("itsa swizzled! 2.0 \(newValue)")

//		let sel = #selector(test(_:didSomething:))
//		if delegate?.responds(to: sel) == true {
//			delegate?.perform(sel, with: newValue)
//		}

		if
			newValue != oldValue,
			let del = delegate as? NetworkHandlerTransferDelegate {

			del.networkHandlerTask(self, stateChanged: newValue)
		}
	}
}
