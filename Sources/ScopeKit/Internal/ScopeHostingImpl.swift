import Combine
import Foundation

protocol ScopeHostingImpl {
    var hostComponent: HostComponent { get }
    var underlying: AnyObject { get }
    var weakHandle: ErasedProvider<AnyScopeHosting?> { get }
    func eraseToAnyScopeHosting() -> AnyScopeHosting

    var ancestors: [AnyScopeHosting] { get }
    var statePublisher: AnyPublisher<ActivityState, Never> { get }

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

    public func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(scopes, to: self.eraseToAnyScopeHosting())
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes, from: self.eraseToAnyScopeHosting())
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes(from: self.eraseToAnyScopeHosting())
    }
}

