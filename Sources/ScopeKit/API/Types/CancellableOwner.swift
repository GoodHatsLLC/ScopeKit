import Combine
import Foundation

public protocol CancellableOwningWhileActive {
    var whileActive: Set<AnyCancellable> { get set }
}
