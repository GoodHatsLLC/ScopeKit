import Combine
import Foundation

public final class CancellableHolderBehavior: Behavior, CancellableReceiver {

    private let holder = CancellableHolder()

    /// Called after the Behavior/Scope is stopped—either when it's directly detached or when an ancestor is no longer attached.
    /// Behavior to be extended by subclass.`super` call is not required.
    public override func didDeactivate() {
        holder.reset()
    }

    public func receive<C>(_ cancellable: C) where C : Cancellable {
        guard state == .active else {
            cancellable.cancel()
            return
        }
        holder.receive(cancellable)
    }

}
