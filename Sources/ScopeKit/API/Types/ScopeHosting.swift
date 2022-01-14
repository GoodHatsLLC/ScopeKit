import Combine
import Foundation

public protocol ScopeHosting {
    /// Erase the specific type of the `ScopeHosting` `self`.
    func eraseToAnyScopeHosting() -> AnyScopeHosting
}

public extension ScopeHosting {
    func host<S: ScopedBehavior>(_ member: S) {
        member.attach(to: self.eraseToAnyScopeHosting())
    }

    func evict<S: ScopedBehavior>(_ member: S) {
        member.detach()
    }
    func host<S: ScopedBehavior>(_ members: [S]) {
        for member in members {
            host(member)
        }
    }

    func evict<S: ScopedBehavior>(_ members: [S]) {
        for member in members {
            evict(member)
        }
    }
}
