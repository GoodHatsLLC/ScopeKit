import Combine
import Foundation

struct BehaviorComponent {
    let behaviorCancellableHolder = CancellableHolder()
    let lifecycleCancellableHolder = CancellableHolder()
    let stateMulticastSubject = CurrentValueSubject<ActivityState, Never>(.detached)
    let hostSubject = CurrentValueSubject<ErasedProvider<AnyScopeHosting?>?, Never>(nil)
}

extension BehaviorComponent {
    
    var host: AnyScopeHosting? {
        hostSubject.value?.value?.weakHandle.value
    }

    var hostPublisher: AnyPublisher<AnyScopeHosting?, Never> {
        hostSubject
            .map { optionalWeakHandle in
                optionalWeakHandle.flatMap { weakHandle in
                    weakHandle.value
                }
            }
            .eraseToAnyPublisher()
    }

    var statePublisher: AnyPublisher<ActivityState, Never> {
        let isDirectlyDetached = hostPublisher
            .map { $0 == nil }

        let directSuperScopeStatePublisher = hostPublisher
            .compactMap { $0 }
            .map { directSuperScope in
                directSuperScope.statePublisher
            }
            .switchToLatest()

        let ownStatePublisher = Publishers.CombineLatest(
            isDirectlyDetached,
            directSuperScopeStatePublisher
        ).map { isDirectlyDetached, superScopeState -> ActivityState in
            switch (isDirectlyDetached, superScopeState) {
            case (true, _):
                return ActivityState.detached
            case (false, .active):
                return ActivityState.active
            case (false, _):
                return ActivityState.attached
            }
        }

        return ownStatePublisher
            .multicast(subject: stateMulticastSubject)
            .autoconnect()
            .eraseToAnyPublisher()
    }

    @discardableResult
    public func attach<HostType>(behavior: AnyScopedBehavior, to host: HostType) -> Future<(), AttachmentError> where HostType: ScopeHosting {
        self.attach(behavior: behavior, to: host.eraseToAnyScopeHosting())
    }

    @discardableResult
    public func attach(behavior: AnyScopedBehavior, to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        Future<(), AttachmentError> { [self] promise in
            hostPublisher
                // first, keep track of any existing parent.
                .first()
                // do nothing if reattaching to same parent.
                .filter { $0 != host }
                .map { potentialFormerParent in
                    // then attach self
                    // self could currently has two parents retaining it
                    host.attachSubscopes([behavior])
                    // but pass any existing parent onwards
                        .map { potentialFormerParent }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { _ in
                    // inform self of new parent
                    hostSubject.send(host.weakHandle)
                })
                // remove the case of no-former-parent
                .compactMap { $0 }
                // finally detach from the former parent to stop its retention
                .map { formerParent in
                    // this call should trigger a `willDetach` call on `self`
                    // but the host from which we are detaching is not the current—
                    // so no action is taken
                    // see (1)
                    formerParent.detachSubscopes([behavior])
                }
                .switchToLatest()
                .map { _ in () }
                .sink {
                    promise(.success(()))
                }
                .store(in: lifecycleCancellableHolder)
        }
    }

    @discardableResult
    func detach(behavior: AnyScopedBehavior) -> Future<(), AttachmentError> {
        Future<(), AttachmentError> { promise in
            hostPublisher
                .first()
                .map { optionalHost in
                    optionalHost.map { host in
                        host.detachSubscopes([behavior])
                            .map { _ in () }
                            .eraseToAnyPublisher()
                    } ?? Just(()).eraseToAnyPublisher()
                }
                .switchToLatest()
                .sink {
                    promise(.success(()))
                }
                .store(in: lifecycleCancellableHolder)
        }
    }
}
