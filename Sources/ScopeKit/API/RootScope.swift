import Combine
import Foundation

public final class RootScope {

    let hostComponent: HostComponent

    public init() {
        self.hostComponent = HostComponent()
    }

}

extension RootScope: ScopeHosting {

    public func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(scopes, to: self.eraseToAnyScopeHosting())
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes, from: self.eraseToAnyScopeHosting())
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes(from: self.eraseToAnyScopeHosting())
    }

    public func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}

extension RootScope: ScopeHostingInternal {

    var statePublisher: AnyPublisher<ScopeState, Never> {
        hostComponent.statePublisher
    }

    var weakHandle: WeakScopeHostingHandle {
        let weak = Weak(self)
        return WeakScopeHostingHandle {
            weak.value?.eraseToAnyScopeHosting()
        }
    }

    var underlying: AnyObject {
        self
    }

}
