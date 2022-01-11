import Combine
import Foundation

open class Scope {

    let hostComponent = HostComponent()
    let scopedBehaviorComponent = BehaviorComponent()
    private let whileActiveCancellableHolder = CancellableHolderBehavior()

    public init() {
        whileActiveCancellableHolder.attach(to: self)
        scopedBehaviorComponent.start(listener: self)
    }

    public var whileActiveReceiver: CancellableReceiver {
        whileActiveCancellableHolder
    }

    /// Called before the Behavior/Scope is attached to a superscope. Always called before activation.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willAttach() {}

    @discardableResult
    public func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        guard !host.ancestors.contains(where: { $0 == self.eraseToAnyScopeHosting() }) else {
            return Future { $0(.failure(AttachmentError.circularAttachment)) }
        }
        return scopedBehaviorComponent.attach(behavior: self.eraseToAnyScopedBehavior(), to: host)
    }

    /// Called before the Behavior/Scope is activated.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willActivate(cancellables: inout Set<AnyCancellable>) {}

    func didActivate() {}

    func willDeactivate() {}

    /// Called after the Behavior/Scope is stopped—either when it's directly detached or when an ancestor is no longer attached.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func didDeactivate() {}


    @discardableResult
    public func detach() -> Future<(), AttachmentError> {
        scopedBehaviorComponent.detach(behavior: self.eraseToAnyScopedBehavior())
    }

    /// Called when the Behavior/Scope is detached from its superscope.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func didDetach() {}

}

extension Scope: ScopedBehavior {
    public var state: ActivityState {
        scopedBehaviorComponent.stateMulticastSubject.value
    }

    public func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}

extension Scope: ScopedBehaviorInternal, BehaviorComponentListener {}

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
