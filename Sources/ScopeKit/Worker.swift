import Combine
import Foundation

public protocol WorkerType {
    func start() -> AnyCancellable
}

open class Worker: WorkerType {

    /// Start the Worker's defined work.
    public final func start() -> AnyCancellable {
        self.willStart()
    }

    /// Override this function to define work begun on `start()`.
    /// Do not call directly.
    /// `super.willStart()` call is not required.
    public func willStart() -> AnyCancellable {
        AnyCancellable({})
    }

}
