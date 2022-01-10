import Combine
import Foundation

public protocol ScopeHosting {

    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never>

    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>

    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never>
    func eraseToAnyScopeHosting() -> AnyScopeHosting
}
