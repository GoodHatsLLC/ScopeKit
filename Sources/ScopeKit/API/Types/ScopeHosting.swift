import Combine
import Foundation

public protocol ScopeHosting: ScopeIdentity {
    var statePublisher: AnyPublisher<ScopeState, Never> { get }
    func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never>
    func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>
    func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never>
}

public extension ScopeHosting {
    func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}
