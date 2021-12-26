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
    public func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(scopes)
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes)
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes()
    }
}
