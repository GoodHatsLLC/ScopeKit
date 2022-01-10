import Combine
import Foundation

public final class CancellableHolderBehavior: Behavior, CancellableReceiver {

    private var holder: CancellableHolder? = nil

    public override func willActivate(cancellables: inout Set<AnyCancellable>) {
        holder = CancellableHolder()
    }

    /// Called after the Behavior/Scope is stopped—either when it's directly detached or when an ancestor is no longer attached.
    /// Behavior to be extended by subclass.`super` call is not required.
    public override func didDeactivate() {
        holder?.cancel()
        holder = nil
    }

    public func receive<C>(_ cancellable: C) where C : Cancellable {
        if let holder = holder {
            holder.receive(cancellable)
            self.holder = holder
        } else {
            cancellable.cancel()
        }
    }

}
