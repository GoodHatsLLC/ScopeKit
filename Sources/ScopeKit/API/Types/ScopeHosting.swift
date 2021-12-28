import Combine
import Foundation

public protocol ScopeHosting {
    func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never>
    func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>
    func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never>
    func eraseToAnyScopeHosting() -> AnyScopeHosting
}
