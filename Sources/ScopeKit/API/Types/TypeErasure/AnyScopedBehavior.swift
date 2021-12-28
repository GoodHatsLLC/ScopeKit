import Combine
import Foundation

public struct AnyScopedBehavior: Hashable {

    public static func == (lhs: AnyScopedBehavior, rhs: AnyScopedBehavior) -> Bool {
        lhs.underlying === rhs.underlying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(underlying))
    }


    private let didAttachFunc: (AnyScopeHosting) -> ()
    private let willDetachFunc: (AnyScopeHosting) -> ()
    private let attachFunc: (AnyScopeHosting) -> (Future<(), AttachmentError>)
    private let detachFunc: () -> (Future<(), AttachmentError>)
    private let stateFunc: () -> ScopeState
    let underlying: AnyObject

    init<T>(from concrete: T) where T: ScopedBehavior, T: ScopedBehaviorInternal {
        underlying = concrete.underlying
        didAttachFunc = { host in concrete.didAttach(to: host) }
        willDetachFunc = { host in concrete.willDetach(from: host) }
        attachFunc = { host in concrete.attach(to: host) }
        detachFunc = { concrete.detach() }
        stateFunc = { concrete.state }
    }
}

extension AnyScopedBehavior: ScopedBehavior {
    public var state: ScopeState {
        stateFunc()
    }

    @discardableResult
    public func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        attachFunc(host)
    }

    @discardableResult
    public func detach() -> Future<(), AttachmentError> {
        detachFunc()
    }

    public func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        self
    }
}

extension AnyScopedBehavior: ScopedBehaviorInternal {
    func didAttach(to host: AnyScopeHosting) {
        didAttachFunc(host)
    }

    func willDetach(from host: AnyScopeHosting) {
        willDetachFunc(host)
    }
}
