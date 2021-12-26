import Combine
import Foundation

open class Scope {

    private let behaviorComponent: BehaviorComponent
    private let hostComponent: HostComponent

    public let id: UUID

    public init() {
        let id = UUID()
        self.id = id
        self.behaviorComponent = BehaviorComponent(id: id)
        self.hostComponent = HostComponent(id: id)
        behaviorComponent.manageBehaviorLifecycle(starting: { [weak self] in
            guard let self = self else {
                return AnyCancellable {}
            }
            return self.start()
        })
    }

}


extension Scope {

    /// Behavior to be extended by subclass.
    open func behavior(cancellables: inout Set<AnyCancellable>){}

    private final func start() -> AnyCancellable {
        var cancellables = Set<AnyCancellable>()
        behavior(cancellables: &cancellables)
        return AnyCancellable {
            cancellables.forEach { cancellable in
                cancellable.cancel()
            }
        }
    }
}

extension Scope: ScopeHosting {
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

extension Scope: ScopedBehavior {
    public func didAttach(to host: AnyScopeHosting) {
        behaviorComponent.didAttach(to: host)
    }

    public func willDetach(from host: AnyScopeHosting) {
        behaviorComponent.willDetach(from: host)
    }

    public func attach(to host: AnyScopeHosting) {
        behaviorComponent.attach(to: host)
    }

    public func detach() {
        behaviorComponent.detach()
    }
}
