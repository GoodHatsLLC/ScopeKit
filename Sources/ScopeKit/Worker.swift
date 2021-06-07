import Combine
import Foundation

public protocol WorkerType {
    func start() -> CancelBaggable
}

open class Worker: WorkerType {

    public init() {}
    /// Start the Worker's defined work.
    public final func start() -> CancelBaggable {
        self.willStart()
    }

    /// Override this function to define work begun on `start()`.
    /// Do not call directly.
    /// `super.willStart()` call is not required.
    open func willStart() -> CancelBaggable {
        AnyCancellable({})
    }

}
