import Foundation

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
