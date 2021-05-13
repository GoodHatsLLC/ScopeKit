import Combine
import XCTest
@testable import ScopeKit

private let testBag = CancelBag()

final class DependencyKitTests: XCTestCase {

    private let root = RootScope()

    override func setUp() {
        print("setUp")
        root.start()
    }

    override func tearDown() {
        root.stop()
        testBag.cancel()
    }

    func testActivation() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(!scope.isSyncActive)
        scope.start()
        XCTAssert(scope.isSyncActive)
    }

    func testAttachmentUpdatesSubjects() {
        let scope = Scope()
        XCTAssertNil(scope.superscopeSubject.value)
        scope.attach(to: root)
        XCTAssert(scope.superscopeSubject.value === root)
    }

    func testDetatchmentUpdatesSubjects() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(scope.superscopeSubject.value === root)
        scope.detach()
        XCTAssertNil(scope.superscopeSubject.value)
    }

    // TODO: must hold children even when not active
    func testAttachmentPreventsRelease() {
        var scope: Scope? = Scope()
        weak var weakSubscope = scope!
        scope?.attach(to: root)
        scope = nil
        XCTAssertNotNil(weakSubscope)
    }

    func testNoInitRetainCycles() {
        var root: Scope? = Scope()
        weak var weakSubscope: Scope? = root
        XCTAssertNotNil(weakSubscope)
        root = nil
        XCTAssertNil(weakSubscope)
    }

    func testDetachmentTriggersRelease() {
        var subscope: Scope? = Scope()
        weak var weakSubscope = subscope
        subscope!.attach(to: root)
        subscope = nil
        XCTAssertNotNil(weakSubscope)
        weakSubscope?.detach()
        XCTAssertNil(weakSubscope)
    }

//    func testMultipleSubscopesAreAttached() {
//        let root = Scope()
//        let subscopes = [Scope(), Scope(), Scope()]
//        XCTAssertEqual(root.subscopesSubject.value.count, 0)
//        XCTAssert(
//            subscopes
//                .map(\.superscopeSubject.value)
//                .allSatisfy { $0 === nil}
//        )
//        subscopes.forEach {
//            $0.attach(to: root)
//        }
//        XCTAssertEqual(root.subscopesSubject.value.count, subscopes.count)
//        XCTAssert(
//            // This asserts order is maintained
//            zip(root.subscopesSubject.value, subscopes)
//                .map(===)
//                .reduce(true) { $0 && $1 }
//        )
//        XCTAssert(
//            subscopes
//                .map(\.superscopeSubject.value)
//                .allSatisfy { $0 === root}
//        )
//    }

    func testActivationUpdatesSubscope() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(!scope.isSyncActive)
        scope.start()
        XCTAssert(scope.isSyncActive)
    }

    func testActivationUpdatesSubscopesRecursively() {
        let scope = Scope()
        let subscope = Scope()
        scope.attach(to: root)
        subscope.attach(to: scope)
        subscope.start()
        XCTAssert(!subscope.isSyncActive)
        scope.start()
        XCTAssert(subscope.isSyncActive)
    }

    func testActivationUpdatesMultipleSubscopes() {
        let scope = Scope()
        scope.attach(to: root)
        let subscopes = [Scope(), Scope(), Scope()]
        subscopes.forEach {
            $0.start()
            $0.attach(to: scope)
        }
        XCTAssert(
            !subscopes
                .map(\.isSyncActive)
                .reduce(false) { $0 || $1 }
        )
        scope.start()
        XCTAssert(
            subscopes
                .map(\.isSyncActive)
                .reduce(true) { $0 && $1 }
        )
    }

    func testAttachmentToInactiveScopeDoesNotActivateScopes() {
        let scope = Scope()
        scope.attach(to: root)
        let subscope = Scope()
        subscope.start()
        XCTAssert(!subscope.isSyncActive)
        subscope.attach(to: scope)
        XCTAssert(!subscope.isSyncActive)
    }

    func testAttachmentToActiveScopeActivatesSubscope() {
        let scope = Scope()
        scope.attach(to: root)
        scope.start()
        let subscope = Scope()
        subscope.start()
        XCTAssert(!subscope.isSyncActive)
        subscope.attach(to: scope)
        XCTAssert(subscope.isSyncActive)
    }

    func testDetatchmentStopsScope() {
        let subscope = Scope()
        subscope.start()
        subscope.attach(to: root)
        XCTAssert(subscope.isSyncActive)
        subscope.detach()
        XCTAssert(!subscope.isSyncActive)
    }

    func testStartCallsWillStart() {
        let scope = ScopeEventReporter()
        scope.attach(to: root)
        XCTAssertEqual(scope.willStartCount, 0)
        scope.start()
        XCTAssertEqual(scope.willStartCount, 1)
    }

    func testStopCallsWillStopOnlyIfPreviouslyStarted() {
        let scope = ScopeEventReporter()
        scope.attach(to: root)
        scope.stop()
        XCTAssertEqual(scope.willStopCount, 0)
        scope.start()
        scope.stop()
        XCTAssertEqual(scope.willStopCount, 1)
    }

    func testEndCallsWillEnd() {
        let scope = ScopeEventReporter()
        scope.attach(to: root)
        XCTAssertEqual(scope.willEndCount, 0)
        scope.end()
        XCTAssertEqual(scope.willEndCount, 1)
    }

    func testStartAfterEndDoesNotFire() {
        let scope = ScopeEventReporter()
        scope.attach(to: root)
        scope.end()
        scope.start()
        XCTAssertEqual(scope.willStartCount, 0)
    }

    func testStartTriggersSubscription() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: root)
        XCTAssertEqual(rep.subscriptionCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.subscriptionCallCount(), 1)
    }

    func testStartTriggersRequest() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: root)
        XCTAssertEqual(rep.requestCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.requestCallCount(), 1)
    }

    func testStartAllowsEvent() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: root)
        XCTAssertEqual(rep.eventCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.eventCallCount(), 1)
    }

    func testStopTriggersCancel() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: root)
        scope.start()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.stop()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

    func testEndTriggersCancel() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: root)
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

extension ScopeType {
    var isSyncActive: Bool {
        var isSyncActive = false
        isActivePublisher.sink {
            isSyncActive = $0
        }.store(in: testBag)
        return isSyncActive
    }
}

class ScopeEventReporter: Scope {

    var willStartCount = 0
    var willStopCount = 0
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

    override func willStop() {
        willStopCount += 1
    }

    override func willEnd() {
        willEndCount += 1
    }
}
