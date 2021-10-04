import Combine
import Foundation

public protocol ScopeOwningType {
    func asScopeOwning() -> ScopeOwning
}

public extension ScopeOwningType where Self: ScopeOwning {
    func asScopeOwning() -> ScopeOwning {
        return self
    }
}

open class ScopeOwning: ScopeOwningType {

    let lifecycleBag = CancelBag()

    // internal for testing
    let subscopesSubject = CurrentValueSubject<[ScopeOwning], Never>([])

    // internal for testing
    var isActivePublisher: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    public init() {}

    func remove(subscope: ScopeOwning) {
        subscopesSubject
            .prefix(1)
            .map { $0.filter { $0 !== subscope} }
            .sink { [weak self] subscopes in
                guard let self = self else { return }
                self.subscopesSubject.send(subscopes)
            }.store(in: lifecycleBag)
    }

    func add(subscope: ScopeOwning) {
        subscopesSubject
            .prefix(1)
            .sink { [weak self] subscopes in
                guard let self = self else { return }
                self.subscopesSubject.send(subscopes + [subscope])
            }.store(in: lifecycleBag)
    }
}
