import Combine
import Foundation


protocol ScopedBehaviorImpl {
    /// required owned / overridden
    var scopedBehaviorComponent: BehaviorComponent { get }
    var statePublisher: AnyPublisher<ActivityState, Never> { get }

    /// provided for objects
    var underlying: AnyObject { get }
    func eraseToAnyScopedBehavior() -> AnyScopedBehavior
}

extension ScopedBehaviorImpl where Self: ScopedBehaviorInternal, Self: AnyObject {

    var underlying: AnyObject {
        self
    }

    func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}


extension ScopedBehaviorImpl where Self: ScopedBehaviorInternal {

    func activate() {
        var cancellables = Set<AnyCancellable>()

        willActivate(cancellables: &cancellables)

        scopedBehaviorComponent.behaviorCancellableHolder.receive(cancellables)

        didActivate()
    }

    func deactivate() {

        willDeactivate()

        scopedBehaviorComponent.behaviorCancellableHolder.reset()

        didDeactivate()
    }

    func willDetach(from detachingHost: AnyScopeHosting) {
        scopedBehaviorComponent.hostPublisher
            .first()
            .sink { [self] currentHost in
                // When the behavior is directly reparented without being
                // detached first the current host is already reset.
                if currentHost == detachingHost {
                    scopedBehaviorComponent.hostSubject.send(nil)
                }
            }
            .store(in: scopedBehaviorComponent.lifecycleCancellableHolder)
    }

    func didAttach(to host: AnyScopeHosting) {
        scopedBehaviorComponent.hostSubject.send(host.weakHandle)
    }

}
