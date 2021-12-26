import Combine
import Foundation

public final class ScopeHost {

    public let id: UUID

    let hostComponent: HostComponent

    public init() {
        let id = UUID()
        self.id = id
        self.hostComponent = HostComponent(id: id)
    }

}

extension ScopeHost: ScopeHosting {

    public var statePublisher: AnyPublisher<ScopeState, Never> {
        hostComponent.statePublisher
    }

    public func retain(scopes: [AnyScopedBehavior]) {
        hostComponent.retain(scopes: scopes)
    }

    public func release(scopes: [AnyScopedBehavior]) {
        hostComponent.release(scopes: scopes)
    }

    public func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(subscopes)
    }

    public func detachSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes()
    }
}
