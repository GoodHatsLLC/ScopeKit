import Foundation
import Combine

public protocol CancellableCollectionConvertible {
    func asCancellableCollection() -> [AnyCancellable]
}

extension Array: CancellableCollectionConvertible where Element == AnyCancellable {
    public func asCancellableCollection() -> [AnyCancellable] {
        self
    }
}

extension Set: CancellableCollectionConvertible where Element == AnyCancellable {
    public func asCancellableCollection() -> [AnyCancellable] {
        self.map{ $0 }
    }
}

extension AnyCollection: CancellableCollectionConvertible where Element == AnyCancellable {
    public func asCancellableCollection() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCancellable: CancellableCollectionConvertible {
    public func asCancellableCollection() -> [AnyCancellable] {
        [self]
    }
}
