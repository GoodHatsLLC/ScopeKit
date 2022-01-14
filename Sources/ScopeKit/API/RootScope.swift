import Combine
import Foundation

public final class RootScope {

    let hostComponent: HostComponent

    public init() {
        self.hostComponent = HostComponent()
    }

}

extension RootScope: ScopeHosting {
    public func eraseToAnyScopeHosting() -> AnyScopeHosting {
        AnyScopeHosting(self)
    }
}


extension RootScope: ScopeHostingImpl {
    var underlying: AnyObject {
        self
    }


    var ancestors: [AnyScopeHosting] {
        [self.eraseToAnyScopeHosting()]
    }

    var statePublisher: AnyPublisher<ActivityState, Never> {
        Just(.active).eraseToAnyPublisher()
    }
}
