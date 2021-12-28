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
}

extension Scope: CancellableOwningWhileActive {
    public var whileActive: Set<AnyCancellable> {
        get {
            Set<AnyCancellable>()
        }
        set {
            externalCancellables.formUnion(newValue)
            cancelExternalCancellablesIfNotActive()
        }
    }

    func cancelExternalCancellablesIfNotActive() {
        statePublisher
            .first()
            .filter { $0 == .detached }
            .map { _ in () }
            .sink {
                self.externalCancellables.forEach { cancellable in
                    cancellable.cancel()
                }
                self.externalCancellables = Set<AnyCancellable>()
            }
            .store(in: &internalCancellables)
    }
}

extension Scope: ScopeHosting {

    public func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
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

extension Scope: ScopeHostingInternal {

    var weakHandle: WeakScopeHostingHandle {
        let weak = Weak(self)
        return WeakScopeHostingHandle {
            weak.value?.eraseToAnyScopeHosting()
        }
    }

}
