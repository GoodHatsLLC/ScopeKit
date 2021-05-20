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

public protocol ScopeType: ScopeOwningType {
    /// Allow this scope to act (iff attached to active superscope)
    func enable()

    /// Disable this scope (even if attached to active superscope)
    func disable()

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    func attach(to superscope: ScopeOwningType)

    /// Remove the Scope from the lifecycle of its superscope.
    func detatch()
}

open class ScopeOwning: ScopeOwningType {

    fileprivate let lifecycleBag = CancelBag()

    // internal for testing
    let subscopesSubject = CurrentValueSubject<[ScopeOwning], Never>([])

    // internal for testing
    var isActivePublisher: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    public init() {}

    fileprivate func remove(subscope: ScopeOwning) {
        subscopesSubject
            .prefix(1)
            .map { $0.filter { $0 !== subscope} }
            .sink { [weak self] subscopes in
                guard let self = self else { return }
                self.subscopesSubject.send(subscopes)
            }.store(in: lifecycleBag)
    }

    fileprivate func add(subscope: ScopeOwning) {
        subscopesSubject
            .prefix(1)
            .sink { [weak self] subscopes in
                guard let self = self else { return }
                self.subscopesSubject.send(subscopes + [subscope])
            }.store(in: lifecycleBag)
    }
}

public final class ScopeRoot: ScopeOwning {
    private let alwaysEnabledSubject = CurrentValueSubject<Bool, Never>(true)
    override var isActivePublisher: AnyPublisher<Bool, Never> {
        alwaysEnabledSubject.eraseToAnyPublisher()
    }

    override public init() {
        super.init()
    }
}

// MARK: Scope
open class Scope: ScopeOwning, ScopeType {

    fileprivate var workBag = CancelBag()

    private let internalIsEnabledSubject = CurrentValueSubject<Bool, Never>(false)

    private var internalIsEnabledPublisher: AnyPublisher<Bool, Never> {
        internalIsEnabledSubject.eraseToAnyPublisher()
    }

    // Internal for testing
    let externalIsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    override var isActivePublisher: AnyPublisher<Bool, Never> {
        externalIsActiveSubject.eraseToAnyPublisher()
    }

    // Internal for testing
    let superscopeSubject = CurrentValueSubject<Weak<ScopeOwning>, Never>(Weak(nil))
    private var superScopeIsEnabledPublisher: AnyPublisher<Bool, Never> {
        superscopeSubject
            .map { $0.get()?.isActivePublisher }
            .replaceNil(with: Just(false).eraseToAnyPublisher())
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    override public init() {
        super.init()
        subscribeToLifecycle()
    }

    deinit {
        externalIsActiveSubject.send(false)
    }

    private func subscribeToLifecycle() {
        // Update retentions in super
        superscopeSubject
            .removeDuplicates { $0.get() === $1.get() }
            .scan((Weak<ScopeOwning>(nil), Weak<ScopeOwning>(nil))) { ($0.1, $1) }
            .sink { [weak self] (curr, next) in
                guard let self = self else { return }
                curr.get()?.remove(subscope: self)
                next.get()?.add(subscope: self)
            }.store(in: lifecycleBag)


        superScopeIsEnabledPublisher
            .combineLatest(internalIsEnabledSubject)
            .map { $0 && $1 }
            .scan((false, false)) { ($0.1, $1) }
            .filter { $0 != $1 } // act only on state changes
            .map { $1 }
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.willStart().store(in: self.workBag)
                }
                // Notify subscopes after enabling self but before disabling self
                self.externalIsActiveSubject.send(enabled)
                if !enabled {
                    self.willStop()
                    self.workBag.cancel()
                }
            }.store(in: lifecycleBag)
    }

    /// Allow this scope to act (iff attached to active superscope)
    public func enable() {
        internalIsEnabledSubject.send(true)
    }

    /// Disable this scope (even if attached to active superscope)
    public func disable() {
        internalIsEnabledSubject.send(false)
    }

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    public func attach(to superscope: ScopeOwningType) {
        superscopeSubject
            .send(Weak(superscope.asScopeOwning()))
    }

    /// Remove the Scope from the lifecycle of its superscope.
    public func detatch() {
        superscopeSubject.send(Weak<ScopeOwning>(nil))
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
