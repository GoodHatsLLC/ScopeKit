import Collections
import Combine
import Foundation

public enum ScopeState {
    case attached
    case detached
}

open class ScopeHost: Equatable, Identifiable, Hashable {

    init(){}

    public static func == (lhs: ScopeHost, rhs: ScopeHost) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var internalCancellables = Set<AnyCancellable>()
    private let subscopesSubject = CurrentValueSubject<Set<Scope>, Never>([])
    public let id = UUID()
    public var statePublisher: AnyPublisher<ScopeState, Never> {
        Just(ScopeState.attached).eraseToAnyPublisher()
    }

    func retain(scopes: [Scope]) {
        subscopesSubject
            .first()
            .sink { subscopes in
                self.subscopesSubject.send(
                    // If we already retain the scope, bump it to the end.
                    subscopes.union(scopes)
                )
            }
            .store(in: &internalCancellables)
    }

    func release(scopes: [Scope]) {
        subscopesSubject
            .first()
            .sink { subscopes in
                let releasedScopes = subscopes.intersection(scopes)
                releasedScopes.forEach { releasedScope in
                    releasedScope.willBeDetached(from: self)
                }
                self.subscopesSubject.send(subscopes.subtracting(releasedScopes))
            }
            .store(in: &internalCancellables)
    }

    final public func detachSubscopes() -> Future<[Scope], Never> {
        // By not using Deferred we avoid the consumer having to sink
        // if they're not interested in keeping the detached Scopes.
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { subscopes in
                    subscopes.forEach { scope in
                        scope.willBeDetached(from: self)
                    }
                    self.subscopesSubject.send([])
                    promise(.success(subscopes.map { $0 }))
                }
                .store(in: &internalCancellables)
        }
    }

    final public func attachSubscopes(_ subscopes: [Scope]) -> Future<(), Never> {
        // By not using Deferred we avoid the consumer having to sink
        // if they're not interested in keeping the detached Scopes.
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { existingSubscopes in
                    self.subscopesSubject.send(existingSubscopes.union(subscopes))
                    subscopes.forEach { scope in
                        scope.didAttach(to: self)
                    }
                    promise(.success(()))
                }
                .store(in: &internalCancellables)
        }
    }


}

final public class ScopeHostRoot: ScopeHost {
    public override init() {
        super.init()
    }
}

open class Scope: ScopeHost {

    public override init() {
        super.init()
        manageBehaviorLifecycle()
    }

    private var behaviorCancellables = Set<AnyCancellable>()

    private func manageBehaviorLifecycle() {
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
                self.start()
            }
            .store(in: &internalCancellables)

        becameInactive
            .sink {
                self.stop()
            }
            .store(in: &internalCancellables)
    }

    final public override var statePublisher: AnyPublisher<ScopeState, Never> {
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
    private let stateMulticastSubject = CurrentValueSubject<ScopeState, Never>(.detached)
    final public var state: ScopeState {
        stateMulticastSubject.value
    }
    final public var host: ScopeHost? {
        hostSubject.value?.value
    }

    private let hostSubject = CurrentValueSubject<Weak<ScopeHost>?, Never>(nil)
    var hostPublisher: AnyPublisher<ScopeHost?, Never> {
        hostSubject
            .map { weakScope -> ScopeHost? in
                guard let value = weakScope?.value else {
                    return nil
                }
                return value
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    final public func attach(to host: ScopeHost) {
        host.retain(scopes: [self])
        hostSubject.send(Weak(host))
    }

    final public func detach() {
        hostPublisher
            .first()
            .sink { host in
                self.hostSubject.send(nil)
                host?.release(scopes: [self])
            }
            .store(in: &internalCancellables)
    }

    final func willBeDetached(from host: ScopeHost) {
        hostPublisher
            .first()
            .filter { $0 === host }
            .map { _ in () }
            .sink {
                self.hostSubject.send(nil)
            }
            .store(in: &internalCancellables)
    }

    final func didAttach(to host: ScopeHost) {
        hostSubject.send(Weak(host))
    }


    open func behavior(cancellables: inout Set<AnyCancellable>) {}

    private func start() {
        var cancellables = Set<AnyCancellable>()

        behavior(cancellables: &cancellables)

        AnyCancellable {
            cancellables.forEach { cancellable in
                cancellable.cancel()
            }
        }
        .store(in: &behaviorCancellables)
    }

    private func stop() {
        let oldBehaviorCancellables = self.behaviorCancellables
        self.behaviorCancellables = Set<AnyCancellable>()

        // Cancel explicitly in case of consumer retention.
        oldBehaviorCancellables.forEach { cancellable in
            cancellable.cancel()
        }
    }

}
