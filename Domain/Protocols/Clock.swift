import Foundation

/// An injectable source of "now", enabling deterministic time in tests.
public protocol Clock: Sendable {
    func now() -> Date
}

/// The production clock backed by the system wall clock.
public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}
