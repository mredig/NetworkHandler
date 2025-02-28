import SwiftPizzaSnips

public struct HTTPHeaders: Hashable, Sendable, MutableCollection, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
	public var startIndex: [HTTPHeader].Index { headers.startIndex }
	public var endIndex: [HTTPHeader].Index { headers.endIndex }

	public typealias Index = [HTTPHeader].Index

	public var headers: [HTTPHeader]

	public init(_ headers: [HTTPHeader]) {
		self.headers = headers
	}

	public init(_ headers: [String: String]) {
		self.init(headers.map { HTTPHeader(key: "\($0.key)", value: "\($0.value)") })
	}

	public init(_ headers: [HTTPHeaderKey: HTTPHeaderValue]) {
		self.init(headers.map { HTTPHeader(key: $0.key, value: $0.value) })
	}

	public init(arrayLiteral elements: HTTPHeader...) {
		self.init(elements)
	}

	public init(dictionaryLiteral elements: (HTTPHeaderKey, HTTPHeaderValue)...) {
		self.init(elements.map { HTTPHeader(key: $0, value: $1) })
	}

	public func index(after i: [HTTPHeader].Index) -> [HTTPHeader].Index {
		headers.index(after: i)
	}

	public subscript(position: [HTTPHeader].Index) -> HTTPHeader {
		get { headers[position] }
		set { headers[position] = newValue }
	}

	/// Removes and optionally returns the header at the given index. Retrieving beyond the end index is illegal!
	@discardableResult
	public mutating func remove(at index: [HTTPHeader].Index) -> HTTPHeader {
		headers.remove(at: index)
	}

	/// Adds a new header to the collection. Allows for duplicating keys.
	public mutating func append(_ new: HTTPHeader) {
		headers.append(new)
	}

	public subscript (key: HTTPHeaderKey) -> HTTPHeaderValue? {
		get {
			headers.first(where: { $0.key == key })?.value
		}

		set {
			let currentIndex = headers.firstIndex(where: { $0.key == key })

			switch (currentIndex, newValue) {
			case (.some(let index), .some(let newValue)):
				let newEntry = HTTPHeader(key: key, value: newValue)
				headers[index] = newEntry
			case (.some(let index), nil):
				headers.remove(at: index)
			case (nil, .some(let newValue)):
				let newEntry = HTTPHeader(key: key, value: newValue)
				headers.append(newEntry)
			case (nil, nil):
				return
			}
		}
	}

	/// Retrieves all the indicies, including duplicates, for a given key.
	public func indicies(for key: HTTPHeaderKey) -> [[HTTPHeader].Index] {
		headers.enumerated().compactMap {
			guard $0.element.key == key else { return nil }
			return $0.offset
		}
	}

	/// Retrieves all the headers, including duplicates, for a given key.
	public func allHeaders(withKey key: HTTPHeaderKey) -> [HTTPHeader] {
		headers.filter { $0.key == key }
	}

	/// Retrieves all used keys
	public func keys() -> [HTTPHeaderKey] {
		headers.map(\.key)
	}
}

public extension HTTPHeaders {
	/// Appends the key/value pair to the headers. Allows duplicate keys.
	mutating func addValue(_ value: HTTPHeaderValue, forKey key: HTTPHeaderKey) {
		append(HTTPHeader(key: key, value: value))
	}

	/// Replaces the first instance of the given key, if it already exists. Otherwise appends.
	mutating func setValue(_ value: HTTPHeaderValue, forKey key: HTTPHeaderKey) {
		self[key] = value
	}

	/// If the provided key is in this instance, returns the value.
	func value(for key: HTTPHeaderKey) -> String? {
		self[key]?.rawValue
	}

	mutating func setContentType(_ contentType: HTTPHeaderValue) {
		setValue(contentType, forKey: .contentType)
	}

	mutating func setAuthorization(_ value: HTTPHeaderValue) {
		setValue(value, forKey: .authorization)
	}
}

public extension HTTPHeaders {
	mutating func combine(with other: HTTPHeaders) {
		headers.append(contentsOf: other.headers)
	}

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
