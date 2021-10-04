import Combine
import Foundation

public final class ScopeRoot: ScopeOwning {
    private let alwaysEnabledSubject = CurrentValueSubject<Bool, Never>(true)
    override var isActivePublisher: AnyPublisher<Bool, Never> {
        alwaysEnabledSubject.eraseToAnyPublisher()
    }

    override public init() {
        super.init()
    }
}
