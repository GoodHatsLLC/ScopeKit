import Combine
import Foundation

private protocol ScopeType: AnyObject {
    var isActivePublisher: AnyPublisher<Bool, Never> { get }
}

public final class RootScope: ScopeType {
    private let isActiveSubject = CurrentValueSubject<Bool, Never>(false)
    var isActivePublisher: AnyPublisher<Bool, Never> {
        isActiveSubject.eraseToAnyPublisher()
    }

    func start() {
        isActiveSubject.send(true)
    }

    func stop() {
        isActiveSubject.send(false)
    }
}

open class Scope: ScopeType {

    private var lifecycleBag = CancelBag()
    fileprivate var workBag = CancelBag()

    private let selfAllowsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    private var selfAllowsActivePublisher: AnyPublisher<Bool, Never> {
        selfAllowsActiveSubject.eraseToAnyPublisher()
    }
    private let superscopeSubject = CurrentValueSubject<ScopeType?, Never>(nil)
    private var superscopePublisher: AnyPublisher<ScopeType?, Never> {
        superscopeSubject
            .removeDuplicates { $0 === $1 }
            .eraseToAnyPublisher()
    }
    

    private var superIsActivePublisher: AnyPublisher<Bool?, Never> {
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

    fileprivate var isActivePublisher: AnyPublisher<Bool, Never> {
        superIsActivePublisher // Does a completion here propagate?
            .replaceNil(with: false)
            .combineLatest(selfAllowsActivePublisher) { $0 && $1 }
            .eraseToAnyPublisher()
    }

    init() { subscribeToLifecycle() }

    private func subscribeToLifecycle() {
        isActivePublisher
            .removeDuplicates()
            .sink(receiveCompletion: { [weak self] _ in
                guard let self = self else { return }
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

    func end() {
        selfAllowsActiveSubject.send(false)
        superscopeSubject.send(nil)
        selfAllowsActiveSubject.send(completion: .finished)
        superscopeSubject.send(completion: .finished)
    }

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    public func attach(to superscope: Scope) {
        superscopeSubject.send(superscope)
    }

    /// Removes the Scope from the lifecycle of its superscope.
    func detach() {
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

/// Mark: Allow use as CancelBag
extension CancelBag {
    func store(in interactor: Scope) {
        self.store(in: interactor.workBag)
    }
}
