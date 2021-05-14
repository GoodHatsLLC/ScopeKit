import Combine

func reportingPublisher<Output>(_ initial: Output) ->
(
    subject: CurrentValueSubject<Output, Error>,
    publisher: AnyPublisher<Output, Error>,
    subscriptionCallCount: () -> Int,
    eventCallCount: () -> Int,
    completionCallCount: () -> Int,
    cancelCallCount: () -> Int,
    requestCallCount: () -> Int
) {
    var subscriptionCallCount = 0
    var eventCallCount = 0
    var completionCallCount = 0
    var cancelCallCount = 0
    var requestCallCount = 0
    let subject = CurrentValueSubject<Output, Error>(initial)
    let publisher = subject.handleEvents { subscription in
        subscriptionCallCount += 1
    } receiveOutput: { event in
        eventCallCount += 1
    } receiveCompletion: { completion in
        completionCallCount += 1
    } receiveCancel: {
        cancelCallCount += 1
    } receiveRequest: { request in
        requestCallCount += 1
    }.eraseToAnyPublisher()
    return (
        subject,
        publisher,
        { subscriptionCallCount },
        { eventCallCount },
        { completionCallCount },
        { cancelCallCount },
        { requestCallCount }
    )
}
