import Combine
import Foundation

open class Scope: Behavior {

    private let hostComponent: HostComponent
    private var externalCancellables = Set<AnyCancellable>()

    public init() {
        let id = UUID()
        self.hostComponent = HostComponent(id: id)
        super.init(id: id)
    }

    final override func willStop() {
        externalCancellables.forEach { cancellable in
            cancellable.cancel()
        }
    }

    public override var statePublisher: AnyPublisher<ScopeState, Never> {
        super.statePublisher
    }
}

extension Scope: CancellableOwningWhileActive {
    public var whileActive: CancellableOwner {
        let owner = CancellableOwner()
        owner
            .eraseToAnyCancellable()
            .store(in: &externalCancellables)
        return owner
    }
}

extension Scope: ScopeHosting {

    public func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(scopes)
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes)
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes()
    }
}

extension Scope {
    public func attach<HostType: ScopeHosting>(to host: HostType) {
        self.attach(to: host.eraseToAnyScopeHosting())
    }
}
