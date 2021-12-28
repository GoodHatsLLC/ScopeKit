import Combine
import Foundation

public final class RootScope {

    let hostComponent: HostComponent

    public init() {
        self.hostComponent = HostComponent()
    }

}

extension RootScope: ScopeHosting {
    public var weakHandle: WeakScopeHostingHandle {
        let weak = Weak(self)
        return WeakScopeHostingHandle {
            weak.value?.eraseToAnyScopeHosting()
        }
    }

    public var underlying: AnyObject {
        self
    }

    public var statePublisher: AnyPublisher<ScopeState, Never> {
        hostComponent.statePublisher
    }
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
