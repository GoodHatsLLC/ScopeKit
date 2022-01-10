import Combine
import Foundation

open class Scope {

    let hostComponent = HostComponent()
    let scopedBehaviorComponent = BehaviorComponent()
    private let whileActiveCancellableHolder = CancellableHolderBehavior()

    public init() {
        whileActiveCancellableHolder.attach(to: self)
        initializeBehaviorLifecycle()
    }

    public var whileActiveReceiver: CancellableReceiver {
        whileActiveCancellableHolder
    }

    @discardableResult
    public func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        guard !host.ancestors.contains(where: { $0 == self.eraseToAnyScopeHosting() }) else {
            return Future { $0(.failure(AttachmentError.circularAttachment)) }
        }
        return scopedBehaviorComponent.attach(behavior: self.eraseToAnyScopedBehavior(), to: host)
    }

    /// Called before the Behavior/Scope is attached to a superscope. Always called before activation.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willAttach() {}

    /// Called before the Behavior/Scope is activated.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willActivate(cancellables: inout Set<AnyCancellable>) {}

    /// Called after the Behavior/Scope is stopped—either when it's directly detached or when an ancestor is no longer attached.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func didDeactivate() {}

    /// Called when the Behavior/Scope is detached from its superscope.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func didDetach() {}

}

extension Scope: ScopedBehavior {
    public var state: ActivityState {
        scopedBehaviorComponent.stateMulticastSubject.value
    }

    @discardableResult
    public func detach() -> Future<(), AttachmentError> {
        scopedBehaviorComponent.detach(behavior: self.eraseToAnyScopedBehavior())
    }

    @discardableResult
    public func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}

extension Scope: ScopedBehaviorInternal {
    func didAttach(to host: AnyScopeHosting) {}
    func didActivate() {}
    func willDeactivate() {}
}

extension Scope: ScopedBehaviorImpl {
    var statePublisher: AnyPublisher<ActivityState, Never> {
        scopedBehaviorComponent.statePublisher
    }
}


extension Scope: ScopeHosting {
    public func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}

extension Scope: ScopeHostingImpl {
    var ancestors: [AnyScopeHosting] {
        let ancestorsExcludingSelf = scopedBehaviorComponent.hostSubject.value?.value?.ancestors ?? []
        return [self.eraseToAnyScopeHosting()] + ancestorsExcludingSelf
    }
}
