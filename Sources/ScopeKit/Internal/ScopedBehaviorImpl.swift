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

    func willDetach(from host: AnyScopeHosting) {
        scopedBehaviorComponent.hostPublisher
            .first()
            .compactMap { $0 }
            // (1) filter to remove any non-current parent callback.
            .filter { $0.underlying === host.underlying }
            .map { _ in () }
            .sink {
                self.scopedBehaviorComponent.hostSubject.send(nil)
            }
            .store(in: scopedBehaviorComponent.lifecycleCancellableHolder)
    }

    func didAttach(to host: AnyScopeHosting) {
        scopedBehaviorComponent.hostSubject.send(host.weakHandle)
    }

}
