import Combine
import Foundation

public struct AnyScopeHosting: Hashable {

    public static func == (lhs: AnyScopeHosting, rhs: AnyScopeHosting) -> Bool {
        lhs.underlying === rhs.underlying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(underlying))
    }

    private let attachFunc: ([AnyScopedBehavior]) -> Future<(), Never>
    private let detachFunc: ([AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>
    private let detachAllFunc: () -> Future<[AnyScopedBehavior], Never>
    let statePublisher: AnyPublisher<ActivityState, Never>
    let weakHandle: WeakScopeHostingHandle
    let underlying: AnyObject

    init<T>(_ concrete: T) where T: ScopeHosting, T: ScopeHostingInternal {
        self.statePublisher = concrete.statePublisher
        self.attachFunc = { scopes in concrete.attachSubscopes(scopes) }
        self.detachFunc = { scopes in concrete.detachSubscopes(scopes) }
        self.detachAllFunc = { concrete.detachAllSubscopes() }
        self.underlying = concrete.underlying
        self.weakHandle = concrete.weakHandle
    }

    public func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never> {
        self.attachFunc(subscopes)
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        self.detachFunc(scopes)
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        self.detachAllFunc()
    }
}

extension AnyScopeHosting: ScopeHosting {
    public func eraseToAnyScopeHosting() -> AnyScopeHosting {
        self
    }
}

extension AnyScopeHosting: ScopeHostingInternal {}
