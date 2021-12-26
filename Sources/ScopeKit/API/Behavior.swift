import Combine
import Foundation

open class Behavior {

    public let id: UUID
    private let behaviorComponent: BehaviorComponent

    public init() {
        let id = UUID()
        self.id = id
        self.behaviorComponent = BehaviorComponent(id: id)
        behaviorComponent.manageBehaviorLifecycle(starting: { [weak self] in
            guard let self = self else {
                return AnyCancellable {}
            }
            return self.start()
        })
    }

}

extension Behavior {

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

extension Behavior: ScopedBehavior {
    public final func didAttach(to host: AnyScopeHosting) {
        behaviorComponent.didAttach(to: host)
    }

    public final func willDetach(from host: AnyScopeHosting) {
        behaviorComponent.willDetach(from: host)
    }

    public func attach(to host: AnyScopeHosting) {
        behaviorComponent.attach(to: host)
    }

    public func detach() {
        behaviorComponent.detach()
    }
}
