import Combine
import Foundation

protocol ScopeHostingImpl {
    var hostComponent: HostComponent { get }
    var underlying: AnyObject { get }
    var weakHandle: ErasedProvider<AnyScopeHosting?> { get }
    func eraseToAnyScopeHosting() -> AnyScopeHosting

    var ancestors: [AnyScopeHosting] { get }
    var statePublisher: AnyPublisher<ActivityState, Never> { get }

    /// Host the passed `scopes` within `self`, binding their activity lifecycle to that of `self`.
    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    ///
    /// If `self` is active, the newly hosted scopes will activate.
    ///
    /// If the passed scopes are already hosted `self` will become the new singular host.
    @discardableResult func host(_ scopes: [AnyScopedBehavior]) -> Future<(), Never>

    /// Evict the passed `scopes`, deactivating them.
    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func evict(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>

    /// Evict all currently hosted scopes, deactivating them.
    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func evictAll() -> Future<[AnyScopedBehavior], Never>

}

extension ScopeHostingImpl where Self: ScopeHosting, Self: AnyObject {

    var weakHandle: ErasedProvider<AnyScopeHosting?> {
        let weak = Weak(self)
        return ErasedProvider {
            weak.value?.eraseToAnyScopeHosting()
        }
    }

}

extension ScopeHostingImpl {

    public func host(_ scopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(scopes, to: self.eraseToAnyScopeHosting())
    }

    public func evict(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes, from: self.eraseToAnyScopeHosting())
    }

    public func evictAll() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes(from: self.eraseToAnyScopeHosting())
    }
}

