# NetworkHandler and NetworkHalpers

NetworkHandler was originally created to reduce boilerplate when using `URLSession`. With the advent of Async/Await in Swift 5.5, that's largely a non issue now. However, there are still some shortcomings of URLSession.

### NetworkHalpers
*Bring some type safety and convenience to constructing a `URLRequest`*

`NetworkHalpers` may be used without `NetworkHandler`. However, `NetworkHandler` depends on `NetworkHalpers`.

* `HTTPMethod`
	* a string backed, extensible, but type safe implementation for HTTP methods with presets for common methods (`GET`, `POST`, etc)
* `HTTPHeaderKey`
	* a string backed, extensible, but type safe implementation for HTTP header keys with presets for common keys (`Authorization`, `Content-Type`, etc)
* `HTTPHeaderValue`
	* a string backed, extensible, but type safe implementation for HTTP header values with presets for some common Content-Types (`image/jpeg`, `application/json`, etc)
* `MultipartFormInputStream`
	* Allows convenient construction of a multipart form constructed via an `InputStream` for efficient form uploading.
* `URLRequest`
	* adds support for utilizing the above types
	* adds `func encodeData<EncodableType: Encodable>(_ encodableType: EncodableType, encoder: NHEncoder? = nil)` as a convenient way to encapsulate data for sending to servers. Uses `URLRequest.defaultEncoder` which can be either a `JSONEncoder` or `PropertyListEncoder` (or any other encoder you create and conform to `NHEncoder`)
	* adds `func setContentType(_ contentType: HTTPHeaderValue)` and `func setAuthorization(_ value: HTTPHeaderValue)` as convenient methods to set exceptionally common headers on requests
* `URL`
	* `var urlRequest: URLRequest` adds convenient creation of a `URLRequest` from a `URL`
	
### NetworkHelper
*Adds robust custom caching, progress tracking, control over how `URLSessionTasks` are constructed, and convenience for mocking on top of `URLSession`*

1. Create and customize a `NetworkRequest` from a url `url.request`
	* in addition to all `URLRequest` properties and methods, you can additionally set the priority that a task will be created, provide a decoder for decoding a `Decodable` response, and provide the expected response code range to have an error automatcially thrown if the code is not within the range.
1. Optionally create an object conforming to `NetworkHandlerTransferDelegate` for progress and state tracking or if you otherwise want to be able to retrieve the associated `URLSessionTask` that is running behind the async method.
1. From an instance of `NetworkHelper` (or the default instance) initiate an async transfer via `transferMahDatas` or `transferMahCodableDatas`
1. ????
1. PROFIT

### Installation:

1. Download and install
	* SPM (recommended)
		1. Add the line `.package(url: "https://github.com/mredig/NetworkHandler.git", .upToNextMinor(from: "1.0.0"))` to the appropriate section of your Package.swift
		1. The Package Name is `NetworkHandler` - add that as a dependency to any targets you want to use it in.
		swift package update or use Xcode
		1. Add `import NetworkHandler` to the top of any file you with to use it in
	* Brute Force Files
		* Alternatively, you could copy all the swift files in the `Sources/NetworkHandler` folder to your project, if you're masochistic.
1. Import to any files you want to use it in
	`import NetworkHandler`
1. Use it!

#### Compatibility
Everything should be compatible with all Apple platforms that support Swift 5.5 with Async/Await.
However, while the previous version was theoretically cross compatible with Linux, this latest iteration is not. I started an attempt (which you can see on the `linux-compatibility` branch), but ultimately it was more involved than the time I had available to proceed with support. Right now, the main obstacle is KVO compatibility for progress tracking a download. If someone is abitious enough, you should be able to get progress information from the delegate's data loaded method and open a PR.
