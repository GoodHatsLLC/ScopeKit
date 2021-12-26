import Combine
import Foundation

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
