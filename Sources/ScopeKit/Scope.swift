import Combine
import Foundation

open class Scope {

    fileprivate var lifecycleBag = CancelBag()
    fileprivate var bag = CancelBag()
    let isActiveSubject = CurrentValueSubject<Bool, Never>(false)
    let superscopeSubject = CurrentValueSubject<Scope?, Never>(nil)
    let subscopesSubject = CurrentValueSubject<[Scope], Never>([])


    init() {
        subscribeToLifecycle()
    }

    private func subscribeToLifecycle() {
        let subscopesSubject = subscopesSubject
        let changeActivation = isActiveSubject
            .dropFirst() // Avoid firing in on init
            .removeDuplicates() // Parent may call without changing state

        changeActivation
            .flatMap { isActive in
                // withLatestFrom
                subscopesSubject
                    .first()
                    .map { (isActive, $0)} }
            .sink(receiveCompletion: { [weak self] _ in
                guard let self = self else { return }
                self.willEnd()
                subscopesSubject.send(completion: .finished)
                self.bag.cancel()
            }, receiveValue: { [weak self] (isActive, subscopes) in
                guard let self = self else { return }
                if isActive {
                    self.willStart().store(in: self.bag)
                    subscopes.forEach {
                        $0.start()
                    }
                } else {
                    self.willSuspend()
                    subscopes.forEach {
                        $0.suspend()
                    }
                    self.bag.cancel()
                }
            }).store(in: lifecycleBag)

        // Handle starting or stopping when a new subscope is attached
        subscopesSubject
            .flatMap { subscopes in
                // withLatestFrom
                changeActivation
                    .first()
                    .map { ($0, subscopes)} }
            .sink { completion in
                // TODO: we should be able to avoid this imperative behavior by subscribing
                // to the parents's lifecycle instead of using these function calls.
                subscopesSubject.value.forEach { scope in
                    scope.end()
                }
            } receiveValue: { (isActive, subscopes) in
                subscopes.forEach { scope in
                    if isActive {
                        scope.start()
                    } else {
                        scope.suspend()
                    }
                }
            }.store(in: lifecycleBag)
    }

    public func start() {
        isActiveSubject.send(true)
    }

    public func suspend() {
        isActiveSubject.send(false)
    }

    func end() {
        isActiveSubject.send(completion: .finished)
        lifecycleBag.cancel()
    }

    // Bind the Scope's lifecycle to the passed Scope as a subscope.
    public func attach(to superscope: Scope) {
        let superscopeSubject = superscopeSubject
        superscope
            .subscopesSubject
            .combineLatest(superscopeSubject)
            .prefix(1)
            .filter { !$0.0.contains{ $0 === self } && $0.1 == nil }
            .sink {
                superscope.subscopesSubject.send( $0.0 + [self])
                superscopeSubject.send(superscope)
            }
            .store(in: bag)
    }

    // Removes the Scope from the lifecycle of its superscope.
    func detach() {
        let superscopeSubject = superscopeSubject
        superscopeSubject
            .compactMap { $0 }
            .flatMap { superscope in
                superscope.subscopesSubject.map { ($0, superscope.subscopesSubject) } }
            .prefix(1)
            .map { ($0.filter { $0 !== self }, $1) }
            .sink { (updatedSubscopes, supersSubscopeSubject) in
                supersSubscopeSubject.send(updatedSubscopes)
                superscopeSubject.send(nil)
                self.end()
            }
            .store(in: bag)
    }


    // MARK: - Subclass API

    // Override to start work done while active.
    // - This will be called on initial start and when restarting after suspension.
    // - Work defined here is cancelled on suspension and on end.
    // - This Scope is started and restarted before its subscopes.
    // - A super call not required.
    open func willStart() -> CancelBag {
        CancelBag()
    }

    // Override to do anything that's useful if the Scope is suspended but not ended.
    // - This is not necessarily called before a scope is ended.
    // - The suspension will cancel work defined in willStart().
    // - If the work in willStart() is cheap to restart, don't do anything here.
    // - Any caching etc. done here must be cleaned up when the scope is fully ended.
    // - A super call not required.
    open func willSuspend() {}

    // Override to do any pre-end cleanup. Executed before subscope stop.
    // - Do any cleanup required. Consider state stored in response to a previous suspension.
    // - A super call not required.
    open func willEnd() {}


}

/// Mark: Allow use as CancelBag
extension CancelBag {
    func store(in interactor: Scope) {
        self.store(in: interactor.bag)
    }
}
