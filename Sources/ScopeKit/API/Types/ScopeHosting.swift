import Combine
import Foundation

public protocol ScopeHosting: ScopeIdentity {
    var statePublisher: AnyPublisher<ScopeState, Never> { get }
    func retain(scopes: [AnyScopedBehavior])
    func release(scopes: [AnyScopedBehavior])
    func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never>
    func detachSubscopes() -> Future<[AnyScopedBehavior], Never>
}

public extension ScopeHosting {
    func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}
