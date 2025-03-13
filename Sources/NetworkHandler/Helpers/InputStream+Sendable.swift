import Foundation

/// Callous conformance to `Sendable` for `InputStream`. While `InputStream` documentation
/// doesn't state that it should be thread safe, there's really no reason it should be accessed by multiple
/// threads anyway as that would inherently corrupt the stream.
extension InputStream: @unchecked @retroactive Sendable {}
