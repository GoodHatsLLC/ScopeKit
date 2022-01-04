import Combine
import Foundation

open class Scope: Behavior {

    private let hostComponent: HostComponent
    private var externalCancellables = Set<AnyCancellable>()

    public override init() {
        self.hostComponent = HostComponent()
        super.init()
    }

    final override func willDeactivate() {
        externalCancellables.forEach { cancellable in
            cancellable.cancel()
        }
    }

    @discardableResult
    public override func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        guard !host.ancestors.contains(where: { $0 == self.eraseToAnyScopeHosting() }) else {
            return Future { $0(.failure(AttachmentError.circularAttachment)) }
        }
        return super.attach(to: host)
    }

}

extension Scope: ReceiverListener {

    func receiveProxied(cancellables: Set<AnyCancellable>) {
        externalCancellables.formUnion(cancellables)
        cancelExternalCancellablesIfNotActive()
    }

    public var whileActiveReceiver: CancellableReceiver {
        CancellableReceiver(listener: self)
    }

    func cancelExternalCancellablesIfNotActive() {
        statePublisher
            .first()
            .filter { $0 != .active }
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
    var ancestors: [AnyScopeHosting] {
        guard let parent = hostSubject.value?.value else {
            return [self.eraseToAnyScopeHosting()]
        }
        return [self.eraseToAnyScopeHosting()] + parent.ancestors
    }


    var weakHandle: ErasedProvider<AnyScopeHosting?> {
        let weak = Weak(self)
        return ErasedProvider {
            weak.value?.eraseToAnyScopeHosting()
        }
    }

}
