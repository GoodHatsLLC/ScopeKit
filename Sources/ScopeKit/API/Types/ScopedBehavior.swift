import Combine
import Foundation

public protocol ScopedBehavior {
    func didAttach(to host: AnyScopeHosting)
    func willDetach(from host: AnyScopeHosting)
    func attach(to host: AnyScopeHosting)
    func detach()
    var underlying: AnyObject { get }
}

public extension ScopedBehavior {
    func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        AnyScopedBehavior(from: self)
    }
}
