import Combine
import Foundation


final class ScopeHost: Scope {
    private let alwaysEnabledSubject = CurrentValueSubject<Bool, Never>(true)
    override var isEnabledPublisher: AnyPublisher<Bool, Never> {
        alwaysEnabledSubject.eraseToAnyPublisher()
    }
}

// MARK: Scope
open class Scope {

    private var lifecycleBag = CancelBag()
    fileprivate var workBag = CancelBag()

    let internalIsEnabledSubject = CurrentValueSubject<Bool, Never>(false)

    var internalIsEnabledPublisher: AnyPublisher<Bool, Never> {
        internalIsEnabledSubject.eraseToAnyPublisher()
    }

    let subscopesSubject = CurrentValueSubject<[Scope], Never>([])

    let externalIsEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    var isEnabledPublisher: AnyPublisher<Bool, Never> {
        externalIsEnabledSubject.eraseToAnyPublisher()
    }

    let superscopeSubject = CurrentValueSubject<Weak<Scope>, Never>(Weak(nil))
    private var superScopeIsEnabledPublisher: AnyPublisher<Bool, Never> {
        superscopeSubject
            .map { $0.get()?.isEnabledPublisher }
            .replaceNil(with: Just(false).eraseToAnyPublisher())
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    init() {
        subscribeToLifecycle()
    }

    deinit {
        externalIsEnabledSubject.send(false)
    }

    private func remove(subscope: Scope) {
        // TODO: sink
        subscopesSubject.value = subscopesSubject.value.filter { $0 !== subscope }
    }

    private func add(subscope: Scope) {
        // TODO: sink
        subscopesSubject.value.append(subscope)
    }

    private func subscribeToLifecycle() {
        // Update retentions in super
        superscopeSubject
            .removeDuplicates { $0.get() === $1.get() }
            .scan((Weak<Scope>(nil), Weak<Scope>(nil))) { ($0.1, $1) }
            .sink { [weak self] (curr, next) in
                guard let self = self else { return }
                curr.get()?.remove(subscope: self)
                next.get()?.add(subscope: self)
            }.store(in: lifecycleBag)


        superScopeIsEnabledPublisher
            .combineLatest(internalIsEnabledSubject)
            .map { $0 && $1 }
            .scan((false, false)) { ($0.1, $1) }
            .filter { $0 != $1 }
            .map { $1 }
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.willStart().store(in: self.workBag)
                }
                // Notify subscopes after enabling self but before disabling self
                self.externalIsEnabledSubject.send(enabled)
                if !enabled {
                    self.willStop()
                    self.workBag.cancel()
                }
            }.store(in: lifecycleBag)
    }

    public func enable() {
        internalIsEnabledSubject.send(true)
    }

    public func disable() {
        internalIsEnabledSubject.send(false)
    }

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    public func attach(to superscope: Scope) {
        superscopeSubject
            .send(Weak(superscope))
    }

    /// Removes the Scope from the lifecycle of its superscope.
    public func detach() {
        superscopeSubject.send(Weak<Scope>(nil))
    }


    // MARK: - Subclass API

    /// Override to start work done while active.
    /// - This will be called both on initial start and when restarting after stopping..
    /// - Work defined here is cancelled on suspension and on end.
    /// - This Scope is started and restarted before its subscopes.
    /// - A super call not required.
    open func willStart() -> CancelBag {
        CancelBag()
    }

    /// Override to do anything that's useful if the Scope is stoped but not necessarily ended.
    /// - The suspension will cancel work defined in willStart().
    /// - If the work in willStart() is cheap to restart, don't do anything here.
    /// - Any caching etc. done here must be cleaned up when the scope is fully ended.
    /// - A super call not required.
    open func willStop() {}

}
