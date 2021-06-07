import Foundation
import Combine

public protocol CancelBaggable {
    func asCancellableCollection() -> [AnyCancellable]
}

extension Array: CancelBaggable where Element == AnyCancellable {
    public func asCancellableCollection() -> [AnyCancellable] {
        self
    }
}

extension Set: CancelBaggable where Element == AnyCancellable {
    public func asCancellableCollection() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCollection: CancelBaggable where Element == AnyCancellable {
    public func asCancellableCollection() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCancellable: CancelBaggable {
    public func asCancellableCollection() -> [AnyCancellable] {
        [self]
    }
}
