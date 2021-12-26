import Combine
import Foundation

public protocol CancellableOwningWhileActive {
    var whileActive: CancellableOwner { get }
}

public class CancellableOwner {
    var externalCancellables = Set<AnyCancellable>()
    public var cancellables: Set<AnyCancellable> {
        externalCancellables
    }
}
