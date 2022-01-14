import Combine
import Foundation

public protocol ScopedBehavior {

    /// The ScopedBehavior's current ``ActivityState``.
    var state: ActivityState { get }

    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError>

    /// The (non-deferred) Future executes immediately. Consumers only need to sink if they care about the result.
    @discardableResult func detach() -> Future<(), AttachmentError>

    func eraseToAnyScopedBehavior() -> AnyScopedBehavior
}

public extension ScopedBehavior {
    @discardableResult func attach<HostType>(to host: HostType) -> Future<(), AttachmentError>
    where HostType: ScopeHosting {
        attach(to: host.eraseToAnyScopeHosting())
    }
}

protocol BehaviorLifecycleHandling {
    func willAttach()
    func didAttach(to host: AnyScopeHosting)
    func willActivate(cancellables: inout Set<AnyCancellable>)
    func activate()
    func didActivate()
    func willDeactivate()
    func deactivate()
    func didDeactivate()
    func willDetach(from host: AnyScopeHosting)
    func didDetach()

}

protocol ScopedBehaviorInternal: ScopedBehavior, BehaviorLifecycleHandling {}
