import Combine
import Foundation

public struct AnyScopedBehavior: ScopedBehavior, Hashable {

    public static func == (lhs: AnyScopedBehavior, rhs: AnyScopedBehavior) -> Bool {
        lhs.underlying === rhs.underlying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(underlying))
    }


    private let didAttachFunc: (AnyScopeHosting) -> ()
    private let willDetachFunc: (AnyScopeHosting) -> ()
    private let attachFunc: (AnyScopeHosting) -> ()
    private let detachFunc: () -> ()
    public let underlying: AnyObject

    init<T: ScopedBehavior>(from type: T) {
        self.underlying = type.underlying
        didAttachFunc = { host in type.didAttach(to: host) }
        willDetachFunc = { host in type.willDetach(from: host) }
        attachFunc = { host in type.attach(to: host) }
        detachFunc = { type.detach() }
    }
}

extension AnyScopedBehavior {
    public func didAttach(to host: AnyScopeHosting) {
        didAttachFunc(host)
    }

    public func willDetach(from host: AnyScopeHosting) {
        willDetachFunc(host)
    }

    public func attach(to host: AnyScopeHosting) {
        attachFunc(host)
    }

    public func detach() {
        detachFunc()
    }
}
