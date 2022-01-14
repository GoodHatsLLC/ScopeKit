import Combine
import Foundation

final class CancellableHolder: CancellableReceiver {

    private var cancellables = Set<AnyCancellable>()

    func receive<C: Cancellable>(_ cancellable: C) {
        cancellable.store(in: &cancellables)
    }

    func reset() {
        cancellables.forEach { cancellable in
            cancellable.cancel()
        }
        cancellables.removeAll()
    }

}
