import Combine
import Foundation

final class HostComponent {

    private var internalCancellables = Set<AnyCancellable>()
    private let subscopesSubject = CurrentValueSubject<Set<AnyScopedBehavior>, Never>([])
    let id: UUID

    init(id: UUID){
        self.id = id
    }
}

extension HostComponent: ScopeHosting {

    var statePublisher: AnyPublisher<ScopeState, Never> {
        Just(ScopeState.attached).eraseToAnyPublisher()
    }

    func retain(scopes: [AnyScopedBehavior]) {
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

    func release(scopes: [AnyScopedBehavior]) {
        subscopesSubject
            .first()
            .sink { subscopes in
                let releasedScopes = subscopes.intersection(scopes)
                releasedScopes.forEach { releasedScope in
                    releasedScope.willDetach(from: self.eraseToAnyScopeHosting())
                }
                self.subscopesSubject.send(subscopes.subtracting(releasedScopes))
            }
            .store(in: &internalCancellables)
    }

    func detachSubscopes() -> Future<[AnyScopedBehavior], Never> {
        // By not using Deferred we avoid the consumer having to sink
        // if they're not interested in keeping the detached Scopes.
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { subscopes in
                    subscopes.forEach { scope in
                        scope.willDetach(from: self.eraseToAnyScopeHosting())
                    }
                    self.subscopesSubject.send([])
                    promise(.success(subscopes.map { $0 }))
                }
                .store(in: &internalCancellables)
        }
    }

    func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never> {
        // By not using Deferred we avoid the consumer having to sink
        // if they're not interested in keeping the detached Scopes.
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { existingSubscopes in
                    self.subscopesSubject.send(existingSubscopes.union(subscopes))
                    subscopes.forEach { scope in
                        scope.didAttach(to: self.eraseToAnyScopeHosting())
                    }
                    promise(.success(()))
                }
                .store(in: &internalCancellables)
        }
    }
}
