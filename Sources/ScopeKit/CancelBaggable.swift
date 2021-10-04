import Foundation
import Combine

// CancelBaggables are things which can be used in the CancelBag resultBuilder
public protocol CancelBaggable {
    func asAnyCancellables() -> [AnyCancellable]
}

extension Array: CancelBaggable where Element == AnyCancellable {
    public func asAnyCancellables() -> [AnyCancellable] {
        self
    }
}

extension Set: CancelBaggable where Element == AnyCancellable {
    public func asAnyCancellables() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCollection: CancelBaggable where Element == AnyCancellable {
    public func asAnyCancellables() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCancellable: CancelBaggable {
    public func asAnyCancellables() -> [AnyCancellable] {
        [self]
    }
}

extension CancelBag: CancelBaggable {
    public func asAnyCancellables() -> [AnyCancellable] {
        cancellables.map { $0 }
    }
}
