import Combine
import Foundation

public struct AnyScopeHosting: ScopeHosting, Hashable {

    public static func == (lhs: AnyScopeHosting, rhs: AnyScopeHosting) -> Bool {
        lhs.underlying === rhs.underlying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(underlying))
    }

    private let attachFunc: ([AnyScopedBehavior]) -> Future<(), Never>
    private let detachFunc: ([AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>
    private let detachAllFunc: () -> Future<[AnyScopedBehavior], Never>
    public let weakHandle: WeakScopeHostingHandle
    public let underlying: AnyObject

    init<T: ScopeHosting>(_ type: T) {
        self.statePublisher = type.statePublisher
        self.attachFunc = { scopes in type.attachSubscopes(scopes) }
        self.detachFunc = { scopes in type.detachSubscopes(scopes) }
        self.detachAllFunc = { type.detachAllSubscopes() }
        self.underlying = type.underlying
        self.weakHandle = type.weakHandle
    }

    public let statePublisher: AnyPublisher<ScopeState, Never>

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
