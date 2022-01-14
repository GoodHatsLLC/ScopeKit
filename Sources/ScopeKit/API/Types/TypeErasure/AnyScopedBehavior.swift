import Combine
import Foundation

public struct AnyScopedBehavior: Hashable {

    public static func == (lhs: AnyScopedBehavior, rhs: AnyScopedBehavior) -> Bool {
        lhs.underlying === rhs.underlying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(underlying))
    }


    private let underlyingObject: AnyObject
    private let scopedBehaviorComponentFunc: () -> BehaviorComponent
    private let statePublisherFunc: () -> AnyPublisher<ActivityState, Never>
    private let internalFunc: () -> ScopedBehaviorInternal

    init<T>(from concrete: T) where T: ScopedBehaviorImpl, T: ScopedBehaviorInternal {
        underlyingObject = concrete.underlying
        scopedBehaviorComponentFunc = { concrete.scopedBehaviorComponent }
        statePublisherFunc = { concrete.statePublisher }
        internalFunc = { concrete as ScopedBehaviorInternal }
    }

    private var sbInternal: ScopedBehaviorInternal { internalFunc() }
}

extension AnyScopedBehavior: ScopedBehaviorImpl {

    var underlying: AnyObject {
        underlyingObject
    }

    public func eraseToAnyScopedBehavior() -> AnyScopedBehavior {
        return self
    }

    var statePublisher: AnyPublisher<ActivityState, Never> {
        statePublisherFunc()
    }

    var scopedBehaviorComponent: BehaviorComponent {
        scopedBehaviorComponentFunc()
    }

}

extension AnyScopedBehavior: ScopedBehaviorInternal {

    func willAttach() {
        sbInternal.willAttach()
    }

    func willActivate(cancellables: inout Set<AnyCancellable>) {
        sbInternal.willActivate(cancellables: &cancellables)
    }

    func didActivate() {
        sbInternal.didActivate()
    }

    func willDeactivate() {
        sbInternal.willDeactivate()
    }

    func didDeactivate() {
        sbInternal.didDeactivate()
    }

    func didDetach() {
        sbInternal.didDetach()
    }

    public func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError> {
        sbInternal.attach(to: host)
    }

    public func detach() -> Future<(), AttachmentError> {
        sbInternal.detach()
    }

    public var state: ActivityState {
        sbInternal.state
    }

}
