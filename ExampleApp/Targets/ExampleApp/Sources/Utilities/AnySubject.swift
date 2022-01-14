import Combine
import Foundation

public final class AnySubject<Output, Failure: Error>: Subject {

    public typealias Output = Output

    private let valueFunc: (Output) -> ()
    private let completionFunc: (Subscribers.Completion<Failure>) -> ()
    private let subscriptionFunc: (Subscription) -> ()
    private let anyPublisher: AnyPublisher<Output, Failure>

    public init<T: Subject>(_ underlying: T)
    where T.Output == Output, T.Failure == Failure {
        self.valueFunc = underlying.send
        self.completionFunc = underlying.send(completion:)
        self.subscriptionFunc = underlying.send(subscription:)
        self.anyPublisher = underlying.eraseToAnyPublisher()
    }

    public func send(_ value: Output) {
        valueFunc(value)
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        completionFunc(completion)
    }

    public func send(subscription: Subscription) {
        subscriptionFunc(subscription)
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        anyPublisher.receive(subscriber: subscriber)
    }

    public func eraseToAnySubject() -> AnySubject<Output, Failure> {
        self
    }
}

public extension Subject {
    func eraseToAnySubject() -> AnySubject<Output, Failure> {
        AnySubject(self)
    }
}
