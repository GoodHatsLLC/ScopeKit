import Combine
import Foundation

public struct AnyScopedBehavior: ScopedBehavior {

    private let didAttachFunc: (AnyScopeHosting) -> ()
    private let willDetachFunc: (AnyScopeHosting) -> ()
    private let attachFunc: (AnyScopeHosting) -> ()
    private let detachFunc: () -> ()

    public let id: UUID

    init<T: ScopedBehavior>(from type: T) {
        id = type.id
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

public extension ScopedBehavior {
    func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}

public class AnyScopeHosting: ScopeHosting {

    private let retainFunc: ([AnyScopedBehavior]) -> ()
    private let releaseFunc: ([AnyScopedBehavior]) -> ()
    private let attachFunc: ([AnyScopedBehavior]) -> Future<(), Never>
    private let detachFunc: () -> Future<[AnyScopedBehavior], Never>

    init<T: ScopeHosting>(_ type: T) {
        self.id = type.id
        self.statePublisher = type.statePublisher
        self.retainFunc = { scopes in type.retain(scopes: scopes) }
        self.releaseFunc = { scopes in type.release(scopes: scopes) }
        self.attachFunc = { scopes in type.attachSubscopes(scopes) }
        self.detachFunc = { type.detachSubscopes() }
    }

    public var id: UUID

    public let statePublisher: AnyPublisher<ScopeState, Never>

    public func retain(scopes: [AnyScopedBehavior]) {
        self.retainFunc(scopes)
    }

    public func release(scopes: [AnyScopedBehavior]) {
        self.releaseFunc(scopes)
    }

    public func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never> {
        self.attachFunc(subscopes)
    }

    public func detachSubscopes() -> Future<[AnyScopedBehavior], Never> {
        self.detachFunc()
    }

}

public extension ScopeHosting {
    func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}
