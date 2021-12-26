import Combine
import Foundation

final class BehaviorComponent {

    private var internalCancellables = Set<AnyCancellable>()
    private var behaviorCancellables = Set<AnyCancellable>()
    private let stateMulticastSubject = CurrentValueSubject<ScopeState, Never>(.detached)
    private let weakHostSubject = CurrentValueSubject<Weak<AnyScopeHosting>?, Never>(nil)
    let id: UUID

    init(
        id: UUID
    ) {
        self.id = id
    }
}

extension BehaviorComponent: ScopedBehavior {

    func manageBehaviorLifecycle(starting: @escaping Startable) {
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
            .sink {
                self.start(starting: starting)
            }
            .store(in: &internalCancellables)

        becameInactive
            .sink {
                self.stop()
            }
            .store(in: &internalCancellables)
    }

    var statePublisher: AnyPublisher<ScopeState, Never> {
        let isDirectlyDetached = weakHostPublisher
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

    var state: ScopeState {
        stateMulticastSubject.value
    }

    var host: AnyScopeHosting? {
        weakHostSubject.value?.value
    }

    var weakHostPublisher: AnyPublisher<Weak<AnyScopeHosting>?, Never> {
        weakHostSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    var hostPublisher: AnyPublisher<AnyScopeHosting?, Never> {
        weakHostPublisher
            .map { weakScope -> AnyScopeHosting? in
                guard let value = weakScope?.value else {
                    return nil
                }
                return value
            }
            .eraseToAnyPublisher()
    }

    func attach(to host: AnyScopeHosting) {
        host.retain(scopes: [self.eraseToAnyScopedBehavior()])
        weakHostSubject.send(Weak(host))
    }

    func detach() {
        hostPublisher
            .first()
            .sink { host in
                self.weakHostSubject.send(nil)
                host?.release(scopes: [self.eraseToAnyScopedBehavior()])
            }
            .store(in: &internalCancellables)
    }

    func willDetach(from host: AnyScopeHosting) {
        weakHostPublisher
            .first()
            .compactMap { $0 }
            .filter { $0.value == host }
            .map { _ in () }
            .sink {
                self.weakHostSubject.send(nil)
            }
            .store(in: &internalCancellables)
    }

    func didAttach(to host: AnyScopeHosting) {
        weakHostSubject.send(Weak(host))
    }

    func start(starting: Startable) {
        starting()
            .store(in: &behaviorCancellables)
    }

    func stop() {
        let oldBehaviorCancellables = self.behaviorCancellables
        self.behaviorCancellables = Set<AnyCancellable>()

        // Cancel explicitly in case of consumer retention.
        oldBehaviorCancellables.forEach { cancellable in
            cancellable.cancel()
        }
    }

}
