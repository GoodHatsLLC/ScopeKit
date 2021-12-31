import Combine
import Foundation

open class Behavior {

    private struct StateTransition: Equatable {
        let previous: ActivityState?
        let current: ActivityState?
    }

    private var behaviorCancellable: AnyCancellable?
    private let stateMulticastSubject = CurrentValueSubject<ActivityState, Never>(.detached)
    private let hostSubject = CurrentValueSubject<ErasedProvider<AnyScopeHosting?>?, Never>(nil)
    var internalCancellables = Set<AnyCancellable>()

    public init() {
        manageBehaviorLifecycle()
    }

    @discardableResult
    public final func attach<HostType: ScopeHosting>(to host: HostType) -> Future<(), AttachmentError> {
        self.attach(to: host.eraseToAnyScopeHosting())
    }

    /// Called before the Behavior/Scope is attached to a superscope. Always called before activation.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willAttach() {}

    /// Called before the Behavior/Scope is activated.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willActivate(cancellables: inout Set<AnyCancellable>) {}

    /// overridden only internally.
    func didActivate() {}

    /// overridden only internally.
    func willDeactivate() {}

    /// Called after the Behavior/Scope is stopped—either when it's directly detached or when an ancestor is no longer attached.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func didDeactivate() {}

    /// Called when the Behavior/Scope is detached from its superscope.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func didDetach() {}

}

// MARK: - Private implementation
extension Behavior {

    private func manageBehaviorLifecycle() {

        statePublisher
            .removeDuplicates()
            .scan(StateTransition(previous: nil, current: nil)) { previousTransition, currentState in
                StateTransition(previous: previousTransition.current, current: currentState)
            }.sink { [weak self] transition in
                guard let self = self else { return }
                switch (transition.previous, transition.current) {
                case (nil, .detached):
                    break
                case (.detached, .attached):
                    self.willAttach()
                case (.detached, .active):
                    self.willAttach()
                    self.start()
                case (.attached, .active):
                    self.start()
                case (.active, .attached):
                    self.stop()
                case (.active, .detached):
                    self.stop()
                    self.didDetach()
                case (.attached, .detached):
                    self.didDetach()
                default:
                    assertionFailure("unexpected state transition")
                    break
                }
                Injection.shared.assert(Thread.isMainThread, "ScopeKit state changes should happen on the main thread.")
            }
            .store(in: &internalCancellables)
    }

    private var host: AnyScopeHosting? {
        hostSubject.value?.value?.weakHandle.value
    }

    private var hostPublisher: AnyPublisher<AnyScopeHosting?, Never> {
        hostSubject
            .map { optionalWeakHandle in
                optionalWeakHandle.flatMap { weakHandle in
                    weakHandle.value
                }
            }
            .eraseToAnyPublisher()
    }

    private func start() {
        var cancellables = Set<AnyCancellable>()

        willActivate(cancellables: &cancellables)

        behaviorCancellable = AnyCancellable {
            cancellables.forEach { cancellable in
                cancellable.cancel()
            }
        }

        didActivate()
    }

    private func stop() {
        willDeactivate()

        // Cancel explicitly in case of consumer retention.
        behaviorCancellable?.cancel()
        behaviorCancellable = nil

        didDeactivate()
    }

}

// MARK: - ScopedBehavior
extension Behavior: ScopedBehavior {

    public var state: ActivityState {
        stateMulticastSubject.value
    }

    public func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        Future<(), AttachmentError> { [self] promise in
            hostPublisher
                // first, keep track of any existing parent.
                .first()
                .map { potentialFormerParent in
                    // then attach self
                    // self could currently has two parents retaining it
                    host.attachSubscopes([self.eraseToAnyScopedBehavior()])
                    // but pass any existing parent onwards
                        .map { potentialFormerParent }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { _ in
                    // inform self of new parent
                    self.hostSubject.send(host.weakHandle)
                })
                // remove the case of no-former-parent
                .compactMap { $0 }
                // finally detach from the former parent to stop its retention
                .map { formerParent in
                    // this call should trigger a `willDetach` call on `self`
                    // but the host from which we are detaching is not the current—
                    // so no action is taken
                    // see (1)
                    formerParent.detachSubscopes([self.eraseToAnyScopedBehavior()])
                }
                .switchToLatest()
                .map { _ in () }
                .sink {
                    promise(.success(()))
                }
                .store(in: &internalCancellables)
        }
    }

    @discardableResult
    public func detach() -> Future<(), AttachmentError> {
        Future<(), AttachmentError> { [self] promise in
            hostPublisher
                .first()
                .map { optionalHost in
                    optionalHost.map { host in
                        host.detachSubscopes([self.eraseToAnyScopedBehavior()])
                            .map { _ in () }
                            .eraseToAnyPublisher()
                    } ?? Just(()).eraseToAnyPublisher()
                }
                .switchToLatest()
                .sink {
                    promise(.success(()))
                }
                .store(in: &internalCancellables)
        }
    }

    public func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}

// MARK: - ScopedBehaviorInternal
extension Behavior: ScopedBehaviorInternal {

    var underlying: AnyObject {
        self
    }

    func willDetach(from host: AnyScopeHosting) {
        hostPublisher
            .first()
            .compactMap { $0 }
            // (1) filter to remove any non-current parent callback.
            .filter { $0.underlying === host.underlying }
            .map { _ in () }
            .sink {
                self.hostSubject.send(nil)
            }
            .store(in: &internalCancellables)
    }

    func didAttach(to host: AnyScopeHosting) {
        hostSubject.send(host.weakHandle)
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
}
