# Network Handler

## Network Handler is now deprecated! 
Async/Await has nearly completely nullified most of the advantages of NetworkHandler. The remaining advantages were primarily the type safety provided by allowing you to specify http methods and headers on `NetworkRequest`, so I've spun off this kind of functionality into `NetworkHalper`. `NetworkHalper` is currently a secondary library supporting the existing NetworkHandler, but will probably eventually be spun off into its own repo.

![Halp](Misc/Halp.jpg)


### NOTE!
the current version says "1.0" even though it is 100% in active development (consider it beta-ish)! The app store, however, freaks out if a version string (or build number) has a 'b' in it (god forbid), so to allow for it to work for appstore submissions, the current version says "1.0".
(It's getting close to what I'd feel comforable releasing, but there are definitely a few things that still need to be smoothed over)

NetworkHandler was written to save you time by cutting out the needlessly messy boilerplate code from `URLSession`. Typically, everytime you make a network call, you have to check for errors, response codes, data existence and data validity. Every. Single.. Time... Skipping those steps while using `URLSession` might result in unforseen consequences. Luckily, we built `NetworkHandler` as a solution.

NetworkHandler consists of 3 core functions:

* `transferMahOptionalDatas`:
	* Occasionally, you want to make network requests without needing to check if data was returned from the server. You use `transferMahOptionalDatas` in these situations to provide you strictly with `Data?` when successful and a `NetworkError` when unsuccessful.
* `transferMahDatas`:
	* This is for situations when you know a successful transaction results in legitimate data. You are then provided with `Data` upon success, and a `NetworkError` upon failure.
* `transferMahCodableDatas`:
	* This is for the specific use case when dealing with JSON apis. You construct your model, `DemoModel` for example, then simply tell the function this is specifically the type you want as a result. (`transferMahCodableDatas(with: urlRequest, completion: (Result<DemoModel, NetworkError>) -> Void)`) Upon success, it'll handle *all of the decoding for you* and simply provide you with data in the custom type you requested! (upon success) Upon failure, of course, it will provide a `NetworkError`.

### Features
NetworkHandler reduces the boilerplate code you need to deal with when making an HTTP request. NetworkHandler is written in Swift 5 to make use of Result type to cut out redundancies.

You might be wondering how much boilerplate mumbo-jumbo it can really cut out.. Well here's an example:

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

* `NetworkCache`:
	* A wrapper for NSCache that make subsequent requests super-zippy-fast
    
* `NetworkMockingSession`:
	* Super easy data mocking
    
* `UIAlertController` Extension (iOS only):
	* Allows you to simply pass in an `Error` and let the alert controller create a user facing alert for you
    
* `URL Extension`:
	* Easy URLRequest generation
    
* `HTTPMethods`:
	* Enum containing common HTTP method strings to set in your requests (keep you from typoing on stringly typed data)
    
* `HTTPHeaderKeys`:
	* Similarly, common keys for HTTP headers
    
* `NetworkError`:
	* Swifty errors for easier error handling
    
* `NetworkHandler`:
	* The bread to the above butter, this class helps with `URLSession.dataTasks`

### Installation:

1. Download and install
	* SPM (recommended)
		1. Add the line `.package(url: "https://github.com/mredig/NetworkHandler.git", from: "0.9.0")` to the appropriate section of your Package.swift
		1. The Package Name is `NetworkHandler` - add that as a dependency to any targets you want to use it in.
		swift package update or use Xcode
		1. Add `import NetworkHandler` to the top of any file you with to use it in
	* Carthage
		* Add this line to your Cartfile then proceed to follow the remaining Cathage setup instructions
			`github "mredig/NetworkHandler"`
	* Brute Force Files
		* Alternatively, you could copy all the swift files in the `Sources/NetworkHandler` folder to your project, if you're masochistic.
	* CocoaPods (not actively maintained or tested, will accept PRs)
		* add this line to your Podfile:
        `  pod 'NetworkHandler', '~> 0.9.3'`
1. Import to any files you want to use it in
	`import NetworkHandler`
1. Use it!

##### Todo
* Readme
	* demo task as return value and cancelling
	* demo mocking data
* NetworkRequest documentation
* NetworkHeaders documentation (file, not type)
* demo new additions in readme
	* network request
	* graphql error message forwarding
	* passing erroneous data for debugging
* update demo for new additions (network request/graphql error forwarding/etc)
* create tests for mocking with input verification
