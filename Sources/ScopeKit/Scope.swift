import Combine
import Foundation

public protocol ScopeType: AnyObject {
    var isActivePublisher: AnyPublisher<Bool, Never> { get }
    func retain(subscope: ScopeType)
    func release(subscope: ScopeType)
}

public final class RootScope: ScopeType {
    // only for retaining
    let subscopesSubject = CurrentValueSubject<[ScopeType], Never>([])
    public func retain(subscope: ScopeType) {
        subscopesSubject.value.append(subscope)
    }

    public func release(subscope: ScopeType) {
        subscopesSubject.value.removeAll { $0 === subscope }
    }

    private let isActiveSubject = CurrentValueSubject<Bool, Never>(false)
    public var isActivePublisher: AnyPublisher<Bool, Never> {
        isActiveSubject.eraseToAnyPublisher()
    }

    public func start() {
        isActiveSubject.send(true)
    }

    public func stop() {
        isActiveSubject.send(false)
    }
}

// MARK: Scope
open class Scope: ScopeType {

    private var lifecycleBag = CancelBag()
    fileprivate var workBag = CancelBag()

    let selfAllowsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    var selfAllowsActivePublisher: AnyPublisher<Bool, Never> {
        selfAllowsActiveSubject.eraseToAnyPublisher()
    }
    let superscopeSubject = CurrentValueSubject<ScopeType?, Never>(nil)
    var superscopePublisher: AnyPublisher<ScopeType?, Never> {
        superscopeSubject
            .removeDuplicates { $0 === $1 }
            .eraseToAnyPublisher()
    }

    // only for retaining
    let subscopesSubject = CurrentValueSubject<[ScopeType], Never>([])

    public func retain(subscope: ScopeType) {
        subscopesSubject.value.append(subscope)
    }

    public func release(subscope: ScopeType) {
        subscopesSubject.value.removeAll { $0 === subscope }
    }


    var superIsActivePublisher: AnyPublisher<Bool?, Never> {
        superscopePublisher
            .map { superscope in
                superscope?
                    .isActivePublisher
                    .map { Optional($0) }
                    .eraseToAnyPublisher()
                ?? Just<Bool?>(nil)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    public var isActivePublisher: AnyPublisher<Bool, Never> {
        superIsActivePublisher // Does a completion here propagate?
            .replaceNil(with: false)
            .combineLatest(selfAllowsActivePublisher) { $0 && $1 }
            .eraseToAnyPublisher()
    }

    init() { subscribeToLifecycle() }

    private struct ScopeScan {
        let last: ScopeType?
        let curr: ScopeType?
    }

    private func subscribeToLifecycle() {
        superscopePublisher
            .removeDuplicates { $0 === $1 }
            .scan(ScopeScan(last: nil, curr: nil)) { prev, newScope in
                ScopeScan(last: prev.curr, curr: newScope)
            }
            .sink { [weak self] scan in
                guard let self = self else { return }
                if let last = scan.last {
                    last.release(subscope: self)
                }
                if let curr = scan.curr {
                    curr.retain(subscope: self)
                }
            }.store(in: lifecycleBag)

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
    }

    public func start() {
        selfAllowsActiveSubject.send(true)
    }

    public func stop() {
        selfAllowsActiveSubject.send(false)
    }

    public func end() {
        selfAllowsActiveSubject.send(false)
        superscopeSubject.send(nil)
        selfAllowsActiveSubject.send(completion: .finished)
        superscopeSubject.send(completion: .finished)
    }

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    public func attach(to superscope: ScopeType) {
        superscopeSubject.send(superscope)
    }

    /// Removes the Scope from the lifecycle of its superscope.
    public func detach() {
        superscopeSubject.send(nil)
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

// MARK: CancelBag Storage
extension CancelBag {
    func store(in interactor: Scope) {
        self.store(in: interactor.workBag)
    }
}
