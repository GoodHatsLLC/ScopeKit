import Combine
import Foundation

public final class AnonymousBehavior: Behavior {

    private let action: (inout Set<AnyCancellable>) -> ()

    public init(_ action: @escaping (inout Set<AnyCancellable>) -> ()) {
        self.action = action
        super.init()
    }

    public override func willActivate(cancellables: inout Set<AnyCancellable>) {
        action(&cancellables)
    }
}
