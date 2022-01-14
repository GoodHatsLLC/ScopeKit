import Combine
import Foundation

public protocol CancellableReceiver {
    func receive<C: Cancellable>(_ cancellable: C)
}

public extension CancellableReceiver {
    func receive<T: Collection>(_ cancellables: T) where T.Element: Cancellable {
        cancellables.forEach { cancellable in
            receive(cancellable)
        }
    }
}

public extension Cancellable {
    func store(in receiver: CancellableReceiver) {
        receiver.receive(self)
    }
}


public final class CancellableHolder: CancellableReceiver {

    private var cancellables = Set<AnyCancellable>()

    public func receive<C: Cancellable>(_ cancellable: C) {
        cancellable.store(in: &cancellables)
    }

    public func reset() {
        cancellables.forEach { cancellable in
            cancellable.cancel()
        }
        cancellables.removeAll()
    }

}
