import Combine
import Foundation

// A Cancelling is the cancellable set used by scopes and workers.
// It could be a collection of AnyCancellables, an AnyCancellable, or a CancelBag.
public protocol Cancelling {
    func asCancelBag() -> CancelBag
}

extension Array: Cancelling where Element == AnyCancellable {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }
}

extension Set: Cancelling where Element == AnyCancellable {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }
}

extension AnyCollection: Cancelling where Element == AnyCancellable {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }
}

extension AnyCancellable: Cancelling {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }
}

extension CancelBag: Cancelling {
    public func asCancelBag() -> CancelBag {
        self
    }
}
