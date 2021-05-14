import Combine
import Foundation


public final class ScopeHost: Owning {

    private let isActiveSubject = CurrentValueSubject<Bool, Never>(true)

    override var isActivePublisher: AnyPublisher<Bool, Never> {
        isActiveSubject.eraseToAnyPublisher()
    }
}

open class StatusPublishing {
    var isActivePublisher: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }
}

open class Owning: StatusPublishing {

    // only for retaining
    let subscopesSubject = CurrentValueSubject<[Owning], Never>([])

    fileprivate func retain(subscope: Owning) {
        subscopesSubject.value.append(subscope)
    }

    fileprivate func release(subscope: Owning) {
        subscopesSubject.value.removeAll { $0 === subscope }
    }

}

private struct ScopeScan {
    let last: Weak<Owning>
    let curr: Weak<Owning>
}

private struct ActiveScan {
    let last: Bool
    let curr: Bool
}

// MARK: Scope
open class Scope: Owning {

    private var lifecycleBag = CancelBag()
    fileprivate var workBag = CancelBag()

    let selfAllowsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    var selfAllowsActivePublisher: AnyPublisher<Bool, Never> {
        selfAllowsActiveSubject
            .eraseToAnyPublisher()
    }
    let superscopeSubject = CurrentValueSubject<Weak<Owning>, Never>(Weak(nil))
    var superscopePublisher: AnyPublisher<Weak<Owning>, Never> {
        superscopeSubject
            .eraseToAnyPublisher()
    }

    private var superIsActivePublisher: AnyPublisher<Bool, Never> {
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
            .replaceNil(with: false)
            .eraseToAnyPublisher()
    }

    private let preExternalIsActiveScanSubject = PassthroughSubject<ActiveScan, Never>()
    private let externalIsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    private let postExternalIsActiveScanSubject = PassthroughSubject<ActiveScan, Never>()

    private var preExternalIsActivePublisher: AnyPublisher<Bool, Never> {
        preExternalIsActiveScanSubject
            .map { $0.curr }
            .eraseToAnyPublisher()
    }

    override var isActivePublisher: AnyPublisher<Bool, Never> {
        externalIsActiveSubject
            .eraseToAnyPublisher()
    }

    private var postExternalIsActivePublisher: AnyPublisher<Bool, Never> {
        postExternalIsActiveScanSubject
            .map { $0.curr }
            .eraseToAnyPublisher()
    }

    override init() {
        super.init()
        subscribeToLifecycle()
    }

    private func subscribeToLifecycle() {
        preExternalIsActivePublisher
            .sink(receiveValue: { [weak self] isActive in
                guard let self = self else { return }
                if isActive {
                    self.willStart()
                        .store(in: self.workBag)
                }
            }).store(in: lifecycleBag)

        postExternalIsActivePublisher
            .sink(receiveCompletion: { [weak self] _ in
                guard let self = self else { return }
                self.willEnd()
                self.workBag.cancel()
                self.lifecycleBag.cancel()
            }, receiveValue: { [weak self] isActive in
                guard let self = self else { return }
                if !isActive {
                    self.willStop()
                    self.workBag.cancel()
                }
            }).store(in: lifecycleBag)

        superscopePublisher
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


        // Order events to allow actions before and after subscopes
        superIsActivePublisher
            .combineLatest(selfAllowsActivePublisher) { $0 && $1 }
            .scan(ActiveScan(last: false, curr: false)) { prev, newScope in
                ActiveScan(last: prev.curr, curr: newScope)
            }
            // Only notify on a state switch
            .filter { $0.last != $0.curr }
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.preExternalIsActiveScanSubject.send(completion: completion)
                self.externalIsActiveSubject.send(completion: completion)
                self.postExternalIsActiveScanSubject.send(completion: completion)
            }, receiveValue: { [weak self] value in
                guard let self = self else { return }
                self.preExternalIsActiveScanSubject.send(value)
                self.externalIsActiveSubject.send(value.curr)
                self.postExternalIsActiveScanSubject.send(value)
            }).store(in: lifecycleBag)
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
    public func attach(to superscope: Owning) {
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
