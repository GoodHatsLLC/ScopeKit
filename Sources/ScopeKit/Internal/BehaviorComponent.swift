import Combine
import Foundation

protocol BehaviorComponentListener: AnyObject, BehaviorLifecycleHandling {}

final class BehaviorComponent {
    private weak var listener: BehaviorComponentListener?
    init() {}
    func start(listener: BehaviorComponentListener) {
        self.listener = listener
        initializeBehaviorLifecycle()
    }
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
        let hostPublisher = hostPublisher.share()

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

    func initializeBehaviorLifecycle() {

        statePublisher
            .removeDuplicates()
            .scan(StateTransition(previous: nil, current: nil)) { previousTransition, currentState in
                StateTransition(previous: previousTransition.current, current: currentState)
            }
            .sink { [weak listener] transition in
                guard let listener = listener else {
                    return
                }
                switch (transition.previous, transition.current) {
                case (nil, .detached):
                    break
                case (.detached, .attached):
                    listener.willAttach()
                case (.detached, .active):
                    listener.willAttach()
                    listener.activate()
                case (.attached, .active):
                    listener.activate()
                case (.active, .attached):
                    listener.deactivate()
                case (.active, .detached):
                    listener.deactivate()
                    listener.didDetach()
                case (.attached, .detached):
                    listener.didDetach()
                default:
                    assertionFailure("unexpected state transition")
                    break
                }
                Injection.shared.assert(Thread.isMainThread, "ScopeKit state changes should happen on the main thread.")
            }
            .store(in: lifecycleCancellableHolder)
    }

    @discardableResult
    public func attach<HostType>(behavior: AnyScopedBehavior, to host: HostType) -> Future<(), AttachmentError> where HostType: ScopeHosting {
        self.attach(behavior: behavior, to: host.eraseToAnyScopeHosting())
    }

    @discardableResult
    public func attach(behavior: AnyScopedBehavior, to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        Future<(), AttachmentError> { [self] promise in
            hostPublisher
                // do nothing if reattaching to same parent.
                .setFailureType(to: AttachmentError.self)
                .map { optionalHost -> AnyPublisher<AnyScopeHosting?, AttachmentError> in
                    if optionalHost == host {
                        return Fail(error: AttachmentError.alreadyAttached)
                            .eraseToAnyPublisher()
                    } else {
                        return Just(optionalHost)
                            .setFailureType(to: AttachmentError.self)
                            .eraseToAnyPublisher()
                    }
                }
                .first()
                .switchToLatest()
                .map { potentialFormerParent in
                    // then attach self
                    // self could currently has two parents retaining it
                    host.host([behavior])
                    // but pass any existing parent onwards
                        .map { potentialFormerParent }
                        .setFailureType(to: AttachmentError.self)
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { _ in
                    // inform self of new parent
                    hostSubject.send(host.weakHandle)
                })
                // finally detach from the potential former parent to stop its retention
                .map { potentialFormerParent in
                    // this call should trigger a `willDetach` call on `self`
                    // but the host from which we are detaching is no longer the
                    // parent so no action is taken.
                    potentialFormerParent?
                        .evict([behavior])
                        .map { _ in () }
                        .setFailureType(to: AttachmentError.self)
                        .eraseToAnyPublisher()
                    ?? Just(())
                        .setFailureType(to: AttachmentError.self)
                        .eraseToAnyPublisher()
                }
                .switchToLatest()
                .first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            promise(.failure(error))
                        case .finished:
                            promise(.success(()))
                        }
                    },
                    receiveValue: {})
                .store(in: lifecycleCancellableHolder)
        }
    }

    @discardableResult
    func detach(behavior: AnyScopedBehavior) -> Future<(), AttachmentError> {
        Future<(), AttachmentError> { [self] promise in
            hostPublisher
                .first()
                .setFailureType(to: AttachmentError.self)
                .map { optionalHost in
                    optionalHost.map { host in
                        host.evict([behavior])
                            .map { _ in () }
                            .setFailureType(to: AttachmentError.self)
                            .eraseToAnyPublisher()
                    } ?? Fail(error: AttachmentError.deallocatedHost)
                        .eraseToAnyPublisher()
                }
                .switchToLatest()
                .first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            promise(.failure(error))
                        case .finished:
                            promise(.success(()))
                        }
                    },
                    receiveValue: {})
                .store(in: lifecycleCancellableHolder)
        }
    }
}
