import Combine
import Foundation


public final class AlwaysActiveScope: ScopeBase {

    private let isActiveSubject = CurrentValueSubject<Bool, Never>(true)

    override var isActivePublisher: AnyPublisher<Bool, Never> {
        isActiveSubject.eraseToAnyPublisher()
    }
}

open class ScopeBase {

    var isActivePublisher: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    // only for retaining
    let subscopesSubject = CurrentValueSubject<[ScopeBase], Never>([])

    fileprivate func retain(subscope: ScopeBase) {
        subscopesSubject.value.append(subscope)
    }

    fileprivate func release(subscope: ScopeBase) {
        subscopesSubject.value.removeAll { $0 === subscope }
    }

}

private struct ScopeScan {
    let last: Weak<ScopeBase>
    let curr: Weak<ScopeBase>
}

// MARK: Scope
open class Scope: ScopeBase {

    private var lifecycleBag = CancelBag()
    fileprivate var workBag = CancelBag()

    let selfAllowsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    var selfAllowsActivePublisher: AnyPublisher<Bool, Never> {
        selfAllowsActiveSubject.eraseToAnyPublisher()
    }
    let superscopeSubject = CurrentValueSubject<Weak<ScopeBase>, Never>(Weak(nil))
    var superscopePublisher: AnyPublisher<Weak<ScopeBase>, Never> {
        superscopeSubject
            .removeDuplicates { $0.get() === $1.get() }
            .eraseToAnyPublisher()
    }

    private var superIsActivePublisher: AnyPublisher<Bool?, Never> {
        superscopePublisher
            .map { superscope in
                superscope.get()?
                    .isActivePublisher
                    .map { Optional($0) }
                    .eraseToAnyPublisher()
                ?? Just<Bool?>(nil)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    override var isActivePublisher: AnyPublisher<Bool, Never> {
        superIsActivePublisher
            .replaceNil(with: false)
            .combineLatest(selfAllowsActivePublisher) { $0 && $1 }
            .eraseToAnyPublisher()
    }

    override init() {
        super.init()
        subscribeToLifecycle()
    }

    private func subscribeToLifecycle() {
        isActivePublisher
            .removeDuplicates()
            .dropFirst(1) // Don't fire Stop for Initial value
            .sink(receiveCompletion: { [weak self] _ in
                guard let self = self else { return }
                self.willEnd()
                self.workBag.cancel()
                self.lifecycleBag.cancel()
            }, receiveValue: { [weak self] isActive in
                guard let self = self else { return }
                if isActive {
                    self.willStart()
                        .store(in: self.workBag)
                } else {
                    self.willStop()
                    self.workBag.cancel()
                }
            }).store(in: lifecycleBag)

        superscopePublisher
            .dropFirst(1) // Don't fire for Initial value
            .removeDuplicates { $0.get() === $1.get() }
            .scan(ScopeScan(last: Weak(nil), curr: Weak(nil))) { prev, newScope in
                ScopeScan(last: prev.curr, curr: newScope)
            }
            .sink { [weak self] scan in
                guard let self = self else { return }
                if let last = scan.last.get() {
                    last.release(subscope: self)
                }
                if let curr = scan.curr.get() {
                    curr.retain(subscope: self)
                }
            }.store(in: lifecycleBag)
    }

    public func enable() {
        selfAllowsActiveSubject.send(true)
    }

    public func disable() {
        selfAllowsActiveSubject.send(false)
    }

    public func dispose() {
        selfAllowsActiveSubject.send(false)
        superscopeSubject.send(Weak(nil))
        selfAllowsActiveSubject.send(completion: .finished)
        superscopeSubject.send(completion: .finished)
    }

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    public func attach(to superscope: ScopeBase) {
        superscopeSubject.send(Weak(superscope))
    }

    /// Removes the Scope from the lifecycle of its superscope.
    public func detach() {
        superscopeSubject.send(Weak(nil))
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

    /// Override to do any pre-end cleanup. Executed after subscopes end.
    /// - Do all local cleanup.
    /// - A super call not required.
    open func willEnd() {}


}
