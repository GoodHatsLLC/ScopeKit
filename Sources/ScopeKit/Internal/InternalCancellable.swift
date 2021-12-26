import Combine
import Foundation


protocol InternalCancellable {
    func cancel()
}
extension InternalCancellable {
    func eraseToAnyCancellable() -> AnyCancellable {
        AnyCancellable { self.cancel() }
    }
}

extension CancellableOwner: InternalCancellable {
    func cancel() {
        externalCancellables.forEach { cancellable in
            cancellable.cancel()
        }
        externalCancellables = Set<AnyCancellable>()
    }
}
