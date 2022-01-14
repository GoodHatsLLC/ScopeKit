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
