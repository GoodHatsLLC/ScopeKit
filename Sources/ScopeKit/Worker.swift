// Copyright © 2021 Included Health

import Combine
import Foundation

protocol WorkerType {
    associatedtype Input
    func start(_ input: Input) -> AnyCancellable
}

extension WorkerType where Input == () {
    func start() -> AnyCancellable {
        start(())
    }
}

class Worker<Input>: WorkerType {

    init(){}

    open func work(input: Input, cancellables: inout Set<AnyCancellable>) {}

    final func start(_ input: Input) -> AnyCancellable {
        var cancellables = Set<AnyCancellable>()
        work(input: input, cancellables: &cancellables)
        return AnyCancellable {
            cancellables.forEach { cancellable in
                cancellable.cancel()
            }
        }
    }
}
