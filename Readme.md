# Network Handler

I wrote this because I found myself repeating a lot of boilerplate code when sending and receiving data with APIs. Essentially, every time I'd want to make a network call, I'd have to check for errors, check the response code, check if there's data, check if the data is valid, and finally use the data. Every. Time. (Sure, you could skip a couple of those steps occasionally, but then you might run into an unforeseen error).

NetworkHandler primarily consists of three main functions:

* `transferMahOptionalDatas`:
	* Sometimes you don't care if the server provides data or there may be a situation where the data MIGHT get returned or it MIGHT not, just as long as the transaction was successful otherwise. In these situations, you can use `transferMahOptionalDatas` and it'll provide you with `Data?` when successful, and a `NetworkError` when failure occurs.
* `transferMahDatas`:
	* This is for situations when you know a successful transaction results in legitimate data. You are then provided with `Data` upon success, and a `NetworkError` upon failure.
* `transferMahCodableDatas`:
	* This is for the specific use case when dealing with JSON apis. You construct your model, `DemoModel` for example, then simply tell the function this is specifically the type you want as a result. (`transferMahCodableDatas(with: urlRequest, completion: (Result<DemoModel, NetworkError>) -> Void)`) Upon success, it'll handle *all of the decoding for you* and simply provide you with data in the custom type you requested! (upon success) Upon failure, of course, it will provide a `NetworkError`.

### Features
This essentially reduces the boilerplate you need to deal with when you make an HTTP network request. It makes use of the Swift 5 Result type for super powers in reducing redundancies.

You might be wondering how much boilerplate it can actually cut out for you. Well here's an example:

#### Used for both examples:
```swift
struct DemoModel: Codable, Equatable {
	let id: UUID
	var title: String
	var subtitle: String
	var imageURL: URL

	init(id: UUID = UUID(), title: String, subtitle: String, imageURL: URL) {
		self.id	= id
		self.title = title
		self.subtitle = subtitle
		self.imageURL = imageURL
	}
}

let baseURL = URL(string: "https://networkhandlertestbase.firebaseio.com/DemoAndTests")!
let getURL = baseURL.appendingPathExtension("json")
```

#### Before (using URLSession.dataTask)
```swift
URLSession.shared.dataTask(with: getURL) { (data, response, error) in
	if let response = response as? HTTPURLResponse {
		if response.statusCode != 200 {
			// probably throw an error here
			print("Received a non 200 http response: \(response.statusCode) in \(#file) line: \(#line)")
			return
		}
	} else {
		// probably throw an error here
		print("Did not receive a proper response code in \(#file) line: \(#line)")
		return
	}

	if let error = error {
		print("There was an error fetching your data: \(error)")
		return
	}

	guard let data = data else {
		// again, probably throw an error here if the data doesn't exist
		return
	}

	do {
		let firebaseResults = try JSONDecoder().decode([String: DemoModel].self, from: data)
		let models = Array(firebaseResults.values).sorted { $0.title < $1.title }
		// do something with your successful result!
		print(models)
	} catch {
		let nullData = "null".data(using: .utf8)
		if data == nullData {
			// there was no actual error, Firebase just returns "null" if there is a request it can't provide data for.
			let models = [DemoModel]()
			// do something with your empty array result!
			print(models)
			return
		}
		// there was an error decoding your data
		[print]("Error loading demo models: \(error)")
	}
}.resume() //and I bet you always forget this! (I know do!)

```

#### After (using NetworkHandler)
```swift
// can only input URLRequests, but an extension is provided for ease of use
let request = getURL.request
NetworkHandler.default.transferMahCodableDatas(with: request) { (result: Result<[String: DemoModel], NetworkError>) in
	do {
		let firebaseResults = try result.get()
		let models = Array(firebaseResults.values).sorted { $0.title < $1.title }
		// do something with your successful result!
		print(models)
	} catch NetworkError.dataWasNull {
		// there was no actual error, Firebase just returns "null" if there is a request it can't provide data for.
		let models = [DemoModel]()
		// do something with your empty array result!
		print(models)
	} catch {
		print("Error loading demo models: \(error)")
	}
}
```

Literally all the same stuff is happening behind the scenes, but there's no point in typing it out every. single. time. It's all boilerplate. Additionally, consider the use case where you have a model controller making network calls, but then in your UI code you instruct your model controller to make the call. If, in the UI code, you need to know the result of that, you are stuck again with having to unwrap optional data, optional error, and potentially optional response over in your UI code. Contrarily, using `NetworkHandler` you can simply pass the result type to your UI code and either use the data or display an error (which is particularly easy with the UIAlertController extension included).

## But wait there's more!
There's also built in mocking! Just toggle it on, tell it if you want to get an error or successful data back (and provide it with what you want), give it a delay to simulate a network transaction, and run it!

Additionally, included are several classes and types:

* NetworkCache:
	* A wrapper for NSCache that can make subsequent requests super zippy fast
* NetworkMockingSession
	* Makes for super easy data mocking
* UIAlertController Extension:
	* This extension allows you to simply pass in an `Error` and let the alert controller automatically create a user facing alert for you.
* URL Extension:
	* Allows for easy URLRequest generation
* HTTPMethods:
	* an enum containing common HTTP method strings to set in your requests (keep you from typoing on stringly typed data)
* HTTPHeaderKeys:
	* Similarly, common keys for HTTP headers
* NetworkError:
	* Swifty errors for easier error handling
* NetworkHandler:
	* The bread to the above butter, the class that helps with URLSession.dataTasks

### Installation:

1. Download and install
	* Carthage
		* I recommend using Carthage. Simply add the following line to your cartfile. (and of course, follow the remaining carthage instructions as usual)
			`github "mredig/NetworkHandler"`
	* Brute Force Files
		* Alternatively, you could copy all the swift files in the `NetworkHandler` folder to your project, if you're masochistic.
	* CocoaPods
		* add this line to your Podfile:
			`  pod 'NetworkHandler', '~> 0.9.2'`
1. Import to any files you want to use it in
	`import NetworkHandler`
1. Use it.

##### Todo
* Readme
	* demo task as return value and cancelling
	* demo mocking data
* create build targets for other platforms.
* there may be more access control fixes needed, but the biggest one was fixed
* fix network error code snippet (```swift)
* swiftlint conformance
