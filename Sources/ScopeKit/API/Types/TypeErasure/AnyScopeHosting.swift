import Combine
import Foundation

public class AnyScopeHosting: ScopeHosting {

    private let attachFunc: ([AnyScopedBehavior]) -> Future<(), Never>
    private let detachFunc: ([AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>
    private let detachAllFunc: () -> Future<[AnyScopedBehavior], Never>

    init<T: ScopeHosting>(_ type: T) {
        self.id = type.id
        self.statePublisher = type.statePublisher
        self.attachFunc = { scopes in type.attachSubscopes(scopes) }
        self.detachFunc = { scopes in type.detachSubscopes(scopes) }
        self.detachAllFunc = { type.detachAllSubscopes() }
    }

    public var id: UUID

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
