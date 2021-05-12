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
        var callCount = 0
        let scope = ScopeEventReporter(willStartCallback: { callCount = $0 })
        XCTAssertEqual(callCount, 0)
        scope.start()
        XCTAssertEqual(callCount, 1)
    }

    func testSuspendCallsWillSuspendOnlyIfPreviouslyStarted() {
        var callCount = 0
        let scope = ScopeEventReporter(willSuspendCallback: { callCount = $0 })
        scope.suspend()
        XCTAssertEqual(callCount, 0)
        scope.start()
        XCTAssertEqual(callCount, 0)
        scope.suspend()
        XCTAssertEqual(callCount, 1)
    }

    func testEndCallsWillEndOnlyIfPreviouslyStarted() {
        var willEndCallCount = 0
        let scope = ScopeEventReporter(willEndCallback: { willEndCallCount = $0 })
        scope.end()
        XCTAssertEqual(willEndCallCount, 0)
        scope.start()
        XCTAssertEqual(willEndCallCount, 0)
        scope.end()
        XCTAssertEqual(willEndCallCount, 1)
    }

    func testStartTriggersSubscription() {
        var subscriptionCallCount = 0
        var eventCallCount = 0
        var completionCallCount = 0
        var cancelCallCount = 0
        var requestCallCount = 0
        let testSubject = CurrentValueSubject<TestEvent, Error>(.state)
            .handleEvents { subscription in
                subscriptionCallCount += 1
            } receiveOutput: { event in
                eventCallCount += 1
            } receiveCompletion: { completion in
                completionCallCount += 1
            } receiveCancel: {
                cancelCallCount += 1
            } receiveRequest: { request in
                requestCallCount += 1
            }

        let scope = ScopeEventReporter(eventPublisher: testSubject.eraseToAnyPublisher())
        XCTAssertEqual(subscriptionCallCount, 0)
        scope.start()
        XCTAssertEqual(subscriptionCallCount, 1)
    }

    func testStartTriggersRequest() {
        var subscriptionCallCount = 0
        var eventCallCount = 0
        var completionCallCount = 0
        var cancelCallCount = 0
        var requestCallCount = 0
        let testSubject = CurrentValueSubject<TestEvent, Error>(.state)
            .handleEvents { subscription in
                subscriptionCallCount += 1
            } receiveOutput: { event in
                eventCallCount += 1
            } receiveCompletion: { completion in
                completionCallCount += 1
            } receiveCancel: {
                cancelCallCount += 1
            } receiveRequest: { request in
                requestCallCount += 1
            }

        let scope = ScopeEventReporter(eventPublisher: testSubject.eraseToAnyPublisher())
        XCTAssertEqual(requestCallCount, 0)
        scope.start()
        XCTAssertEqual(requestCallCount, 1)
    }

    func testStartAllowsEvent() {
        var subscriptionCallCount = 0
        var eventCallCount = 0
        var completionCallCount = 0
        var cancelCallCount = 0
        var requestCallCount = 0
        let testSubject = CurrentValueSubject<TestEvent, Error>(.state)
            .handleEvents { subscription in
                subscriptionCallCount += 1
            } receiveOutput: { event in
                eventCallCount += 1
            } receiveCompletion: { completion in
                completionCallCount += 1
            } receiveCancel: {
                cancelCallCount += 1
            } receiveRequest: { request in
                requestCallCount += 1
            }

        let scope = ScopeEventReporter(eventPublisher: testSubject.eraseToAnyPublisher())
        XCTAssertEqual(eventCallCount, 0)
        scope.start()
        XCTAssertEqual(eventCallCount, 1)
    }

    func testSuspendTriggersCancel() {
        var subscriptionCallCount = 0
        var eventCallCount = 0
        var completionCallCount = 0
        var cancelCallCount = 0
        var requestCallCount = 0
        let testSubject = CurrentValueSubject<TestEvent, Error>(.state)
            .handleEvents { subscription in
                subscriptionCallCount += 1
            } receiveOutput: { event in
                eventCallCount += 1
            } receiveCompletion: { completion in
                completionCallCount += 1
            } receiveCancel: {
                cancelCallCount += 1
            } receiveRequest: { request in
                requestCallCount += 1
            }

        let scope = ScopeEventReporter(eventPublisher: testSubject.eraseToAnyPublisher())
        scope.start()
        XCTAssertEqual(cancelCallCount, 0)
        scope.suspend()
        XCTAssertEqual(cancelCallCount, 1)
    }

    func testEndTriggersCancel() {
        var subscriptionCallCount = 0
        var eventCallCount = 0
        var completionCallCount = 0
        var cancelCallCount = 0
        var requestCallCount = 0
        let testSubject = CurrentValueSubject<TestEvent, Error>(.state)
            .handleEvents { subscription in
                subscriptionCallCount += 1
            } receiveOutput: { event in
                eventCallCount += 1
            } receiveCompletion: { completion in
                completionCallCount += 1
            } receiveCancel: {
                cancelCallCount += 1
            } receiveRequest: { request in
                requestCallCount += 1
            }

        let scope = ScopeEventReporter(eventPublisher: testSubject.eraseToAnyPublisher())
        scope.start()
        XCTAssertEqual(cancelCallCount, 0)
        scope.end()
        XCTAssertEqual(cancelCallCount, 1)
    }

    func testEndTriggersCompletion() {
        var subscriptionCallCount = 0
        var eventCallCount = 0
        var completionCallCount = 0
        var cancelCallCount = 0
        var requestCallCount = 0
        let testSubject = CurrentValueSubject<TestEvent, Error>(.state)
            .handleEvents { subscription in
                subscriptionCallCount += 1
            } receiveOutput: { event in
                eventCallCount += 1
            } receiveCompletion: { completion in
                completionCallCount += 1
            } receiveCancel: {
                cancelCallCount += 1
            } receiveRequest: { request in
                requestCallCount += 1
            }

        let scope = ScopeEventReporter(eventPublisher: testSubject.eraseToAnyPublisher())
        scope.start()
        XCTAssertEqual(completionCallCount, 0)
        scope.end()
        XCTAssertEqual(completionCallCount, 1)
    }

}

enum TestEvent {
    case state
}

class ScopeEventReporter: Scope {

    private let willStartCallback: ((Int) -> ())?
    private var willStartCallCount = 0
    private let willSuspendCallback: ((Int) -> ())?
    private var willSuspendCallCount = 0
    private let willEndCallback: ((Int) -> ())?
    private var willEndCallCount = 0

    private let eventPublisher: AnyPublisher<TestEvent, Error>

    required init(eventPublisher: AnyPublisher<TestEvent, Error> = Empty<TestEvent, Error>().eraseToAnyPublisher(),
                  willStartCallback: ((Int) -> ())? = nil,
                  willSuspendCallback: ((Int) -> ())? = nil,
                  willEndCallback: ((Int) -> ())? = nil) {
        self.eventPublisher = eventPublisher
        self.willStartCallback = willStartCallback
        self.willSuspendCallback = willSuspendCallback
        self.willEndCallback = willEndCallback
    }

    override func willStart() -> CancelBag {
        willStartCallCount += 1
        willStartCallback?(willStartCallCount)
        return CancelBag {
            eventPublisher
                .sink(receiveCompletion: {_ in}, receiveValue: {_ in})
        }
    }

    override func willSuspend() {
        willSuspendCallCount += 1
        willSuspendCallback?(willSuspendCallCount)
    }

    override func willEnd() {
        willEndCallCount += 1
        willEndCallback?(willEndCallCount)
    }
}
