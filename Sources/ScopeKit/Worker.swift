import Combine
import Foundation

public protocol WorkerType {
    func start() -> Cancelling
}

open class Worker: WorkerType {

    public init() {}
    /// Start the Worker's defined work.
    public final func start() -> Cancelling {
        self.willStart()
    }

    /// Override this function to define work begun on `start()`.
    /// Do not call directly.
    /// `super.willStart()` call is not required.
    open func willStart() -> Cancelling {
        AnyCancellable({})
    }

}
