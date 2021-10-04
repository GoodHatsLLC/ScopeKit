import Combine
import Foundation

// A Cancelling is the cancellable set used by scopes and workers.
// It could be a collection of AnyCancellables, an AnyCancellable, or a CancelBag.
public protocol Cancelling {
    func asCancelBag() -> CancelBag
    func asAnyCancellables() -> [AnyCancellable]
}

extension Array: Cancelling where Element == AnyCancellable {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }

    public func asAnyCancellables() -> [AnyCancellable] {
        self
    }
}

extension Set: Cancelling where Element == AnyCancellable {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }

    public func asAnyCancellables() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCollection: Cancelling where Element == AnyCancellable {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }

    public func asAnyCancellables() -> [AnyCancellable] {
        self.map { $0 }
    }
}

extension AnyCancellable: Cancelling {
    public func asCancelBag() -> CancelBag {
        CancelBag { self }
    }

    public func asAnyCancellables() -> [AnyCancellable] {
        [self]
    }
}

extension CancelBag: Cancelling {
    public func asCancelBag() -> CancelBag {
        self
    }

    public func asAnyCancellables() -> [AnyCancellable] {
        release()
    }
}
