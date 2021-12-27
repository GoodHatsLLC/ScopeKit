import Combine
import Foundation

public struct WeakScopeHostingHandle {

    private let weakProvider: () -> AnyScopeHosting?

    init(weakProvider: @escaping () -> AnyScopeHosting?) {
        self.weakProvider = weakProvider
    }

    var value: AnyScopeHosting? {
        weakProvider()
    }
}

public protocol ScopeHosting {
    var statePublisher: AnyPublisher<ScopeState, Never> { get }
    func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never>
    func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never>
    func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never>
    var underlying: AnyObject { get }
    var weakHandle: WeakScopeHostingHandle { get }
}

public extension ScopeHosting {
    func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}
