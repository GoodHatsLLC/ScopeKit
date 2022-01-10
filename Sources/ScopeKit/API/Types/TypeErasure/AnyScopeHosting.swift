import Combine
import Foundation

public struct AnyScopeHosting: Hashable {

    public static func == (lhs: AnyScopeHosting, rhs: AnyScopeHosting) -> Bool {
        lhs.underlying === rhs.underlying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(underlying))
    }

    private let hostComponentFunc: () -> HostComponent
    private let ancestorsFunc: () -> [AnyScopeHosting]
    private let statePublisherFunc: () -> AnyPublisher<ActivityState, Never>
    let weakHandle: ErasedProvider<AnyScopeHosting?>
    let underlying: AnyObject

    init<T>(_ concrete: T) where T: ScopeHostingImpl, T: ScopeHosting {
        self.hostComponentFunc = { concrete.hostComponent }
        self.ancestorsFunc = { concrete.ancestors }
        self.statePublisherFunc = { concrete.statePublisher }
        self.underlying = concrete.underlying
        self.weakHandle = concrete.weakHandle
    }
}

extension AnyScopeHosting: ScopeHosting {
    public func eraseToAnyScopeHosting() -> AnyScopeHosting {
        self
    }
}

extension AnyScopeHosting: ScopeHostingImpl {

    public func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(subscopes, to: self)
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes, from: self)
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes(from: self)
    }

    var statePublisher: AnyPublisher<ActivityState, Never> {
        statePublisherFunc()
    }

    var hostComponent: HostComponent {
        hostComponentFunc()
    }

    var ancestors: [AnyScopeHosting] {
        ancestorsFunc()
    }
}
