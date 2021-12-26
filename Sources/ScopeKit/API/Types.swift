import Combine
import Foundation

public enum ScopeState {
    case attached
    case detached
}

public protocol ScopeIdentity: Identifiable, Hashable {
    var id: UUID { get }
}

extension ScopeIdentity {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public protocol ScopedBehavior: ScopeIdentity {
    func didAttach(to host: AnyScopeHosting)
    func willDetach(from host: AnyScopeHosting)
    func attach(to host: AnyScopeHosting)
    func detach()
}


public protocol ScopeHosting: ScopeIdentity {
    var statePublisher: AnyPublisher<ScopeState, Never> { get }
    func retain(scopes: [AnyScopedBehavior])
    func release(scopes: [AnyScopedBehavior])
    func attachSubscopes(_ subscopes: [AnyScopedBehavior]) -> Future<(), Never>
    func detachSubscopes() -> Future<[AnyScopedBehavior], Never>
}
