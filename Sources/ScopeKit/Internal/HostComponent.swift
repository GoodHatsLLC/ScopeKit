import Combine
import Foundation

final class HostComponent {

    private var internalCancellables = Set<AnyCancellable>()
    private let subscopesSubject = CurrentValueSubject<Set<AnyScopedBehavior>, Never>([])

    init(){}
}

extension HostComponent {

    func detachAllSubscopes(from owner: AnyScopeHosting) -> Future<[AnyScopedBehavior], Never> {
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { subscopes in
                    subscopes.forEach { releasedScope in
                        releasedScope.willDetach(from: owner)
                    }
                    self.subscopesSubject.send([])
                    promise(.success(subscopes.map { $0 }))
                }
                .store(in: &internalCancellables)
        }
    }

    func detachSubscopes(_ scopes: [AnyScopedBehavior], from owner: AnyScopeHosting) -> Future<[AnyScopedBehavior], Never> {
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { subscopes in
                    let releasedScopes = subscopes.intersection(scopes)
                    releasedScopes.forEach { releasedScope in
                        releasedScope.willDetach(from: owner)
                    }
                    self.subscopesSubject.send(subscopes.subtracting(releasedScopes))
                    promise(.success(releasedScopes.map { $0 }))
                }
                .store(in: &internalCancellables)
        }
    }

    func attachSubscopes(_ scopes: [AnyScopedBehavior], to owner: AnyScopeHosting) -> Future<(), Never> {
        // By not using Deferred we avoid the consumer having to sink
        // if they're not interested in keeping the detached Scopes.
        Future { [self] promise in
            subscopesSubject
                .first()
                .sink { existingSubscopes in
                    self.subscopesSubject.send(existingSubscopes.union(scopes))
                    scopes.forEach { scope in
                        scope.didAttach(to: owner)
                    }
                    promise(.success(()))
                }
                .store(in: &internalCancellables)
        }
    }
}
