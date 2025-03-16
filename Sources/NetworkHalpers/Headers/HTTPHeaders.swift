import SwiftPizzaSnips

/// Represents a collection of HTTP headers, allowing for both key-value access and
/// duplicate header keys. Provides conformance to various protocols for flexibility,
/// including `Codable`, `MutableCollection`, and `ExpressibleByArrayLiteral`.
public struct HTTPHeaders:
	Sendable,
	Codable,
	MutableCollection,
	ExpressibleByArrayLiteral,
	ExpressibleByDictionaryLiteral {

	public var startIndex: [Header].Index { headers.startIndex }
	public var endIndex: [Header].Index { headers.endIndex }

	public typealias Index = [Header].Index

	/// The array of headers stored in this collection.
	public var headers: [Header]

	/// Creates an instance of `HTTPHeaders` with the provided array of headers.
	/// - Parameter headers: An array of `Header` instances to initialize the collection.
	public init(_ headers: [Header]) {
		self.headers = headers
	}

	/// Creates an instance of `HTTPHeaders` from a dictionary of key-value pairs.
	/// - Parameter headers: A dictionary where keys and values are `String` representations
	///   of header keys and values.
	public init(_ headers: [String: String]) {
		self.init(headers.map { Header(key: "\($0.key)", value: "\($0.value)") })
	}

	/// Creates an instance of `HTTPHeaders` from a dictionary of strongly-typed header key-value pairs.
	/// - Parameter headers: A dictionary where keys are `Header.Key` and values are `Header.Value`.
	public init(_ headers: [Header.Key: Header.Value]) {
		self.init(headers.map { Header(key: $0.key, value: $0.value) })
	}

	/// Creates an instance of `HTTPHeaders` using an array literal of `Header` instances.
	/// - Parameter elements: A variadic list of `Header` instances.
	public init(arrayLiteral elements: Header...) {
		self.init(elements)
	}

	/// Creates an instance of `HTTPHeaders` using a dictionary literal of strongly-typed key-value pairs.
	/// - Parameter elements: A variadic list of tuples where each key is a `Header.Key` and each
	/// value is a `Header.Value`.
	public init(dictionaryLiteral elements: (Header.Key, Header.Value)...) {
		self.init(elements.map { Header(key: $0, value: $1) })
	}

	public func index(after i: [Header].Index) -> [Header].Index {
		headers.index(after: i)
	}

	public subscript(position: [Header].Index) -> Header {
		get { headers[position] }
		set { headers[position] = newValue }
	}

	/// Removes and returns the header at the specified index.
	/// - Parameter index: The position of the header to remove.
	/// - Returns: The removed `Header`.
	/// - Note: This function must not be called with an index beyond `endIndex`. Doing so will cause a runtime error.
	@discardableResult
	public mutating func remove(at index: [Header].Index) -> Header {
		headers.remove(at: index)
	}

	/// Adds a new header to the collection. Duplicate keys are allowed.
	/// - Parameter new: The `Header` to append.
	public mutating func append(_ new: Header) {
		headers.append(new)
	}

	/// Access the value of a specific header using its `Header.Key`.
	/// - Parameter key: The key of the desired header.
	/// - Returns: The value of the header if it exists, or `nil` if not present.
	/// You may also set this subscript to replace or remove headers.
	/// Setting a value to `nil` removes the corresponding key.
	public subscript (key: Header.Key) -> Header.Value? {
		get {
			headers.first(where: { $0.key == key })?.value
		}

		set {
			let currentIndex = headers.firstIndex(where: { $0.key == key })

			switch (currentIndex, newValue) {
			case (.some(let index), .some(let newValue)):
				let newEntry = Header(key: key, value: newValue)
				headers[index] = newEntry
			case (.some(let index), nil):
				headers.remove(at: index)
			case (nil, .some(let newValue)):
				let newEntry = Header(key: key, value: newValue)
				headers.append(newEntry)
			case (nil, nil):
				return
			}
		}
	}

	/// Retrieves all indices (including duplicates) for a given key.
	/// - Parameter key: The key for which to find indices.
	/// - Returns: An array of indices where the given key is located.
	public func indicies(for key: Header.Key) -> [[Header].Index] {
		headers.enumerated().compactMap {
			guard $0.element.key == key else { return nil }
			return $0.offset
		}
	}

	/// Retrieves all headers with a given key, including duplicates.
	/// - Parameter key: The key to search for.
	/// - Returns: An array of `Header` instances matching the given key.
	public func allHeaders(withKey key: Header.Key) -> [Header] {
		headers.filter { $0.key == key }
	}

	/// Retrieves all keys used in this instance.
	/// - Returns: An array of `Header.Key` entries used as keys in this instance.
	public func keys() -> [Header.Key] {
		headers.map(\.key)
	}
}

public extension HTTPHeaders {
	/// Appends a new key-value pair to the headers, allowing duplicate keys.
	/// - Parameters:
	///   - value: The value to append.
	///   - key: The key to append.
	mutating func addValue(_ value: Header.Value, forKey key: Header.Key) {
		append(Header(key: key, value: value))
	}

	/// Sets or replaces the value for a specific key. If the key does not exist, it will be added. If there
	/// are duplicates, it only replaces the first.
	/// - Parameters:
	///   - value: The new value to set. If nil, the key is removed.
	///   - key: The key to update.
	mutating func setValue(_ value: Header.Value?, forKey key: Header.Key) {
		self[key] = value
	}

	/// Retrieves the value for a given key if it exists. If there are duplicates, returns the first instance.
	/// - Parameter key: The `Header.Key` to look up.
	/// - Returns: The associated value as a `String`, or nil if not found.
	func value(for key: Header.Key) -> String? {
		self[key]?.rawValue
	}

	/// Sets the `Content-Type` header.
	/// - Parameter contentType: The value to set for the `Content-Type` header.
	mutating func setContentType(_ contentType: Header.Value) {
		setValue(contentType, forKey: .contentType)
	}

	/// Sets the `Authorization` header.
	/// - Parameter value: The value to set for the `Authorization` header.
	mutating func setAuthorization(_ value: Header.Value) {
		setValue(value, forKey: .authorization)
	}
}

public extension HTTPHeaders {
	/// Combines the headers from another `HTTPHeaders` instance into the current instance.
	/// - Parameter other: The `HTTPHeaders` instance to combine.
	mutating func combine(with other: HTTPHeaders) {
		headers.append(contentsOf: other.headers)
	}

	/// Combines the headers from another `HTTPHeaders` instance into a new instance.
	/// - Parameter other: The `HTTPHeaders` instance to combine.
	/// - Returns: A new `HTTPHeaders` instance with combined headers.
	func combining(with other: HTTPHeaders) -> HTTPHeaders {
		var new = self
		new.combine(with: other)
		return new
	}

	static func + (lhs: HTTPHeaders, rhs: HTTPHeaders) -> HTTPHeaders {
		lhs.combining(with: rhs)
	}

	static func += (lhs: inout HTTPHeaders, rhs: HTTPHeaders) {
		lhs.combine(with: rhs)
	}
}

extension HTTPHeaders: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String {
		headers
			.map { "\($0.key): \($0.value)" }
			.joined(separator: "\n")
	}

	public var debugDescription: String {
		"\(Self.self):\n\(description.prefixingLines(with: "\t"))"
	}
}

extension HTTPHeaders: Equatable {
	private var canonicalVersion: HTTPHeaders {
		var copy = self
		copy.headers.sort {
			if $0.key != $1.key {
				$0.key < $1.key
			} else {
				$0.value < $1.value
			}
		}
		return copy
	}

	public static func == (lhs: HTTPHeaders, rhs: HTTPHeaders) -> Bool {
		lhs.canonicalVersion.headers == rhs.canonicalVersion.headers
	}
}

extension HTTPHeaders: Hashable {
	public func hash(into hasher: inout Hasher) {
		let canonicalVersion = canonicalVersion
		hasher.combine(canonicalVersion.headers)
		hasher.combine(canonicalVersion.startIndex)
		hasher.combine(canonicalVersion.endIndex)
	}
}
