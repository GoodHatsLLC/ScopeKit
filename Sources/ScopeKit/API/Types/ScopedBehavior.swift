import Combine
import Foundation

public protocol ScopedBehavior: ScopeIdentity {
    func didAttach(to host: AnyScopeHosting)
    func willDetach(from host: AnyScopeHosting)
    func attach(to host: AnyScopeHosting)
    func detach()
}

public extension ScopedBehavior {
    func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}
