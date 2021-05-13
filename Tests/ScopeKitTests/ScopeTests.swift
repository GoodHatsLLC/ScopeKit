import Combine
import XCTest
@testable import ScopeKit

final class DependencyKitTests: XCTestCase {

    func testActivation() {
        let scope = Scope()
        XCTAssert(!scope.isActiveSubject.value)
        scope.start()
        XCTAssert(scope.isActiveSubject.value)
    }

    func testAttachmentUpdatesSubjects() {
        let root = Scope()
        let subscope = Scope()
        XCTAssert(root.subscopesSubject.value.isEmpty)
        XCTAssertNil(subscope.superscopeSubject.value)
        subscope.attach(to: root)
        XCTAssertEqual(root.subscopesSubject.value.count, 1)
        XCTAssert(root.subscopesSubject.value.first === subscope)
        XCTAssert(subscope.superscopeSubject.value === root)
    }

    func testDetatchmentUpdatesSubjects() {
        let root = Scope()
        let subscope = Scope()
        subscope.attach(to: root)
        XCTAssertEqual(root.subscopesSubject.value.count, 1)
        XCTAssert(root.subscopesSubject.value.first === subscope)
        XCTAssert(subscope.superscopeSubject.value === root)
        subscope.detach()
        XCTAssertEqual(root.subscopesSubject.value.count, 0)
        XCTAssertNil(subscope.superscopeSubject.value)
    }

    func testAttachmentPreventsRelease() {
        let root = Scope()
        var subscope: Scope? = Scope()
        weak var weakSubscope = subscope.map { $0 }
        subscope?.attach(to: root)
        subscope = nil
        XCTAssertNotNil(weakSubscope)
        XCTAssert(root.subscopesSubject.value.first === weakSubscope)
    }

    func testNoInitRetainCycles() {
        var root: Scope? = Scope()
        weak var weakSubscope: Scope? = root
        XCTAssertNotNil(weakSubscope)
        root = nil
        XCTAssertNil(weakSubscope)
    }

    func testDetachmentTriggersRelease() {
        let root = Scope()
        Scope().attach(to: root)
        weak var weakSubscope = root.subscopesSubject.value.first
        XCTAssertNotNil(weakSubscope)
        weakSubscope?.detach()
        XCTAssertNil(weakSubscope)
    }

    func testStartTriggersReceive() {

    }

    func testMultipleSubscopesAreAttached() {
        let root = Scope()
        let subscopes = [Scope(), Scope(), Scope()]
        XCTAssertEqual(root.subscopesSubject.value.count, 0)
        XCTAssert(
            subscopes
                .map(\.superscopeSubject.value)
                .allSatisfy { $0 === nil}
        )
        subscopes.forEach {
            $0.attach(to: root)
        }
        XCTAssertEqual(root.subscopesSubject.value.count, subscopes.count)
        XCTAssert(
            // This asserts order is maintained
            zip(root.subscopesSubject.value, subscopes)
                .map(===)
                .reduce(true) { $0 && $1 }
        )
        XCTAssert(
            subscopes
                .map(\.superscopeSubject.value)
                .allSatisfy { $0 === root}
        )
    }

    func testActivationUpdatesSubscope() {
        let root = Scope()
        let subscope = Scope()
        subscope.attach(to: root)
        XCTAssert(!subscope.isActiveSubject.value)
        root.start()
        XCTAssert(subscope.isActiveSubject.value)
    }

    func testActivationUpdatesSubscopesRecursively() {
        let root = Scope()
        let subscope = Scope()
        let subSubscope = Scope()
        subscope.attach(to: root)
        subSubscope.attach(to: subscope)
        XCTAssert(!subscope.isActiveSubject.value)
        root.start()
        XCTAssert(subSubscope.isActiveSubject.value)
    }

    func testActivationUpdatesMultipleSubscopes() {
        let root = Scope()
        let subscopes = [Scope(), Scope(), Scope()]
        subscopes.forEach {
            $0.attach(to: root)
        }
        XCTAssert(
            !subscopes
                .map(\.isActiveSubject.value)
                .reduce(false) { $0 || $1 }
        )
        root.start()
        XCTAssert(
            subscopes
                .map(\.isActiveSubject.value)
                .reduce(true) { $0 && $1 }
        )
    }

    func testAttachmentToInactiveScopeDoesNotActivateScopes() {
        let root = Scope()
        let subscope = Scope()
        XCTAssert(!root.isActiveSubject.value)
        XCTAssert(!subscope.isActiveSubject.value)
        subscope.attach(to: root)
        XCTAssert(!root.isActiveSubject.value)
        XCTAssert(!subscope.isActiveSubject.value)
    }

    func testAttachmentToActiveScopeActivatesSubscope() {
        let root = Scope()
        let subscope = Scope()
        root.start()
        XCTAssert(!subscope.isActiveSubject.value)
        subscope.attach(to: root)
        XCTAssert(subscope.isActiveSubject.value)
    }

    func testAttachmentToInactiveScopeStopsSubscope() {
        let root = Scope()
        let subscope = Scope()
        subscope.start()
        XCTAssert(subscope.isActiveSubject.value)
        subscope.attach(to: root)
        XCTAssert(!subscope.isActiveSubject.value)
    }

    func testDetatchmentDoesNotStopScopes() {
        let root = Scope()
        let subscope = Scope()
        subscope.attach(to: root)
        root.start()
        XCTAssert(root.isActiveSubject.value)
        XCTAssert(subscope.isActiveSubject.value)
        subscope.detach()
        XCTAssert(root.isActiveSubject.value)
        XCTAssert(subscope.isActiveSubject.value)
    }

    func testStartCallsWillStart() {
        let scope = ScopeEventReporter()
        XCTAssertEqual(scope.willStartCount, 0)
        scope.start()
        XCTAssertEqual(scope.willStartCount, 1)
    }

    func testSuspendCallsWillSuspendOnlyIfPreviouslyStarted() {
        let scope = ScopeEventReporter()
        scope.suspend()
        XCTAssertEqual(scope.willSuspendCount, 0)
        scope.start()
        scope.suspend()
        XCTAssertEqual(scope.willSuspendCount, 1)
    }

    func testEndCallsWillEndOnlyIfPreviouslyStarted() {
        let scope = ScopeEventReporter()
        scope.end()
        XCTAssertEqual(scope.willEndCount, 0)
        scope.start()
        scope.end()
        XCTAssertEqual(scope.willEndCount, 1)
    }

    func testStartTriggersSubscription() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        XCTAssertEqual(rep.subscriptionCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.subscriptionCallCount(), 1)
    }

    func testStartTriggersRequest() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        XCTAssertEqual(rep.requestCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.requestCallCount(), 1)
    }

    func testStartAllowsEvent() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        XCTAssertEqual(rep.eventCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.eventCallCount(), 1)
    }

    func testSuspendTriggersCancel() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.start()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.suspend()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

    func testEndTriggersCancel() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.start()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.end()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

}

enum TestEvent {
    case state
}

func reportingPublisher<Output>(_ initial: Output) -> (
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

class ScopeEventReporter: Scope {

    var willStartCount = 0
    var willSuspendCount = 0
    var willEndCount = 0

    private let eventPublisher: AnyPublisher<TestEvent, Error>

    required init(eventPublisher: AnyPublisher<TestEvent, Error> = Empty<TestEvent, Error>().eraseToAnyPublisher()) {
        self.eventPublisher = eventPublisher
    }

    override func willStart() -> CancelBag {
        willStartCount += 1
        return CancelBag {
            eventPublisher
                .sink(receiveCompletion: {_ in }, receiveValue: {_ in })
        }
    }

    override func willSuspend() {
        willSuspendCount += 1
    }

    override func willEnd() {
        willEndCount += 1
    }
}
