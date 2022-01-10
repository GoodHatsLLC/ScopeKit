import Combine
import Foundation

open class Behavior {

    let scopedBehaviorComponent = BehaviorComponent()

    public init() {
        scopedBehaviorComponent.start(listener: self)
    }

    @discardableResult
    public func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        return scopedBehaviorComponent.attach(behavior: self.eraseToAnyScopedBehavior(), to: host)
    }

    /// Called before the Behavior/Scope is attached to a superscope. Always called before activation.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willAttach() {}

    /// Called before the Behavior/Scope is activated.
    /// Behavior to be extended by subclass.`super` call is not required.
    open func willActivate(cancellables: inout Set<AnyCancellable>) {}

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

extension Behavior: ScopedBehavior {
    public var state: ActivityState {
        scopedBehaviorComponent.stateMulticastSubject.value
    }

    @discardableResult
    public func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}

extension Behavior: ScopedBehaviorInternal, BehaviorComponentListener {}

extension Behavior: ScopedBehaviorImpl {
    var statePublisher: AnyPublisher<ActivityState, Never> {
        scopedBehaviorComponent.statePublisher
    }
}
