import Combine
import Foundation

open class Behavior {

    private var behaviorCancellable: AnyCancellable?
    private let stateMulticastSubject = CurrentValueSubject<ScopeState, Never>(.detached)
    private let hostSubject = CurrentValueSubject<WeakScopeHostingHandle?, Never>(nil)
    var internalCancellables = Set<AnyCancellable>()

    init() {
        manageBehaviorLifecycle()
    }

    /// overridden only internally.
    func willStop(){}

    /// Behavior to be extended by subclass.
    /// Note: `super` call is not required.
    open func willStart(cancellables: inout Set<AnyCancellable>) {}

    /// Notification of stop.
    /// Note: `super` call is not required.
    open func didStop() {}

    var statePublisher: AnyPublisher<ScopeState, Never> {
        let isDirectlyDetached = hostPublisher
            .filter { $0 == nil }
            .map { _ in ScopeState.detached }

        let directSuperScopeStatePublisher = hostPublisher
            .compactMap { $0 }
            .map { directSuperScope in
                directSuperScope.statePublisher
            }
            .switchToLatest()

        return Publishers.Merge(isDirectlyDetached,
                                directSuperScopeStatePublisher)
            .removeDuplicates()
            .multicast(subject: stateMulticastSubject)
            .autoconnect()
            .eraseToAnyPublisher()
    }

    public var underlying: AnyObject {
        self
    }
}


extension Behavior: ScopedBehavior {

    public func attach(to host: AnyScopeHosting) {
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
            .sink {}
            .store(in: &internalCancellables)
    }

    public func detach() {
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
            .sink {}
            .store(in: &internalCancellables)
    }

    public func willDetach(from host: AnyScopeHosting) {
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

    public func didAttach(to host: AnyScopeHosting) {
        hostSubject.send(host.weakHandle)
    }

}


extension Behavior {

    func manageBehaviorLifecycle() {
        let isActive = statePublisher
            .map { $0 == .attached }
            .removeDuplicates()

        let becameActive = isActive
            .filter { $0 == true }
            .map { _ in () }

        let becameInactive = isActive
            .filter { $0 == false }
            .map { _ in () }

        becameActive
            .sink { [weak self] in
                guard let self = self else {
                    return
                }
                self.start()
            }
            .store(in: &internalCancellables)

        becameInactive
            .sink { [weak self] in
                guard let self = self else {
                    return
                }
                self.stop()
            }
            .store(in: &internalCancellables)
    }

    var state: ScopeState {
        stateMulticastSubject.value
    }

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

    func start() {
        var cancellables = Set<AnyCancellable>()

        willStart(cancellables: &cancellables)

        behaviorCancellable = AnyCancellable {
            cancellables.forEach { cancellable in
                cancellable.cancel()
            }
        }
    }

    func stop() {
        willStop()

        // Cancel explicitly in case of consumer retention.
        behaviorCancellable?.cancel()
        behaviorCancellable = nil

        didStop()
    }

}
