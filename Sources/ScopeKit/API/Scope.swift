import Combine
import Foundation

open class Scope: Behavior {

    private let hostComponent: HostComponent
    private var externalCancellables = Set<AnyCancellable>()

    public override init() {
        self.hostComponent = HostComponent()
        super.init()
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

    public var weakHandle: WeakScopeHostingHandle {
        let weak = Weak(self)
        return WeakScopeHostingHandle {
            weak.value?.eraseToAnyScopeHosting()
        }
    }

    public func attachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<(), Never> {
        hostComponent.attachSubscopes(scopes, to: self.eraseToAnyScopeHosting())
    }

    public func detachSubscopes(_ scopes: [AnyScopedBehavior]) -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachSubscopes(scopes, from: self.eraseToAnyScopeHosting())
    }

    public func detachAllSubscopes() -> Future<[AnyScopedBehavior], Never> {
        hostComponent.detachAllSubscopes(from: self.eraseToAnyScopeHosting())
    }
}

extension Scope {
    public func attach<HostType: ScopeHosting>(to host: HostType) {
        self.attach(to: host.eraseToAnyScopeHosting())
    }
}
