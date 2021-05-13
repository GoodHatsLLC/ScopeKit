import Combine
import XCTest
@testable import ScopeKit

private let testBag = CancelBag()

final class DependencyKitTests: XCTestCase {

    private let activeRoot = RootScope()

    override func setUp() {
        activeRoot.start()
    }

    override func tearDown() {
        activeRoot.stop()
        testBag.cancel()
    }

    func testActivation() {
        let scope = Scope()
        scope.attach(to: activeRoot)
        XCTAssert(!scope.isSyncActive)
        scope.start()
        XCTAssert(scope.isSyncActive)
    }

    func testAttachmentUpdatesSubjects() {
        let scope = Scope()
        XCTAssertNil(scope.superscopeSubject.value.get())
        XCTAssertNil(activeRoot.subscopesSubject.value.first)
        scope.attach(to: activeRoot)
        XCTAssert(scope.superscopeSubject.value.get() === activeRoot)
        XCTAssert(activeRoot.subscopesSubject.value.first === scope)
    }

    func testMultipleSubscopeAttatchmentAndOrdering() {
        let subscopes = [Scope(), Scope(), Scope()]
        XCTAssertEqual(activeRoot.subscopesSubject.value.count, 0)
        XCTAssert(
            subscopes
                .map(\.superscopeSubject.value)
                .allSatisfy { $0.get() === nil}
        )
        subscopes.forEach {
            $0.attach(to: activeRoot)
        }
        XCTAssertEqual(activeRoot.subscopesSubject.value.count, subscopes.count)
        XCTAssert(
            // This asserts order is maintained
            zip(activeRoot.subscopesSubject.value, subscopes)
                .map(===)
                .reduce(true) { $0 && $1 }
        )
        XCTAssert(
            subscopes
                .map(\.superscopeSubject.value)
                .allSatisfy { $0.get() === activeRoot}
        )
    }

    func testDetatchmentUpdatesSubjects() {
        let scope = Scope()
        scope.attach(to: activeRoot)
        XCTAssert(scope.superscopeSubject.value.get() === activeRoot)
        XCTAssert(activeRoot.subscopesSubject.value.first === scope)
        scope.detach()
        XCTAssertNil(scope.superscopeSubject.value.get())
        XCTAssertNil(activeRoot.subscopesSubject.value.first)
    }

    func testAttachmentPreventsRelease() {
        var scope: Scope? = Scope()
        weak var weakSubscope = scope!
        scope?.attach(to: activeRoot)
        scope = nil
        XCTAssertNotNil(weakSubscope)
    }

    func testDoesNotRetainSelf() {
        var scope: Scope? = Scope()
        weak var weakScope: Scope? = scope
        XCTAssertNotNil(weakScope)
        scope = nil
        XCTAssertNil(weakScope)
    }

    func testDoesNotRetainSuperscope() {
        var superscope: Scope? = Scope()
        weak var weakSuperscope: Scope? = superscope
        let scope = Scope()
        scope.attach(to: superscope!)
        XCTAssertNotNil(weakSuperscope)
        superscope = nil
        XCTAssertNil(weakSuperscope)
    }

    func testDetachmentTriggersRelease() {
        var subscope: Scope? = Scope()
        weak var weakSubscope = subscope
        subscope!.attach(to: activeRoot)
        subscope = nil
        XCTAssertNotNil(weakSubscope)
        weakSubscope?.detach()
        XCTAssertNil(weakSubscope)
    }

    func testActivationUpdatesSubscope() {
        let scope = Scope()
        scope.attach(to: activeRoot)
        XCTAssert(!scope.isSyncActive)
        scope.start()
        XCTAssert(scope.isSyncActive)
    }

    func testActivationUpdatesSubscopesRecursively() {
        let scope = Scope()
        let subscope = Scope()
        scope.attach(to: activeRoot)
        subscope.attach(to: scope)
        subscope.start()
        XCTAssert(!subscope.isSyncActive)
        scope.start()
        XCTAssert(subscope.isSyncActive)
    }

    func testActivationUpdatesMultipleSubscopes() {
        let scope = Scope()
        scope.attach(to: activeRoot)
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
        scope.attach(to: activeRoot)
        let subscope = Scope()
        subscope.start()
        XCTAssert(!subscope.isSyncActive)
        subscope.attach(to: scope)
        XCTAssert(!subscope.isSyncActive)
    }

    func testAttachmentToActiveScopeActivatesSubscope() {
        let scope = Scope()
        scope.attach(to: activeRoot)
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
        subscope.attach(to: activeRoot)
        XCTAssert(subscope.isSyncActive)
        subscope.detach()
        XCTAssert(!subscope.isSyncActive)
    }

    func testStartCallsWillStart() {
        let scope = ScopeEventReporter()
        scope.attach(to: activeRoot)
        XCTAssertEqual(scope.willStartCount, 0)
        scope.start()
        XCTAssertEqual(scope.willStartCount, 1)
    }

    func testStopCallsWillStopOnlyIfPreviouslyStarted() {
        let scope = ScopeEventReporter()
        scope.attach(to: activeRoot)
        scope.stop()
        XCTAssertEqual(scope.willStopCount, 0)
        scope.start()
        scope.stop()
        XCTAssertEqual(scope.willStopCount, 1)
    }

    func testEndCallsWillEnd() {
        let scope = ScopeEventReporter()
        scope.attach(to: activeRoot)
        XCTAssertEqual(scope.willEndCount, 0)
        scope.end()
        XCTAssertEqual(scope.willEndCount, 1)
    }

    func testStartAfterEndDoesNotFire() {
        let scope = ScopeEventReporter()
        scope.attach(to: activeRoot)
        scope.end()
        scope.start()
        XCTAssertEqual(scope.willStartCount, 0)
    }

    func testStartTriggersSubscription() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: activeRoot)
        XCTAssertEqual(rep.subscriptionCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.subscriptionCallCount(), 1)
    }

    func testStartTriggersRequest() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: activeRoot)
        XCTAssertEqual(rep.requestCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.requestCallCount(), 1)
    }

    func testStartAllowsEvent() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: activeRoot)
        XCTAssertEqual(rep.eventCallCount(), 0)
        scope.start()
        XCTAssertEqual(rep.eventCallCount(), 1)
    }

    func testStopTriggersCancel() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: activeRoot)
        scope.start()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.stop()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

    func testEndTriggersCancel() {
        let rep = reportingPublisher(TestEvent.state)
        let scope = ScopeEventReporter(eventPublisher: rep.publisher)
        scope.attach(to: activeRoot)
        scope.start()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.end()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

    func testWillStartCascadeBeginsAtSuperscope() {
        var superscopeStarted = false
        var subscopeStarted = false
        let superscope = LifecycleCallbackScope(start: {
            XCTAssert(!subscopeStarted)
            superscopeStarted = true
        })
        superscope.start()
        let subscope = LifecycleCallbackScope(start: {
            XCTAssert(superscopeStarted)
            subscopeStarted = true
        })
        subscope.start()
        subscope.attach(to: superscope)
        XCTAssert(!superscopeStarted)
        XCTAssert(!subscopeStarted)
        superscope.attach(to: activeRoot) // ooh. not sufficient to start?
        XCTAssert(superscopeStarted)
        XCTAssert(subscopeStarted)
    }

    func testWillSuspendCascadeBeginsAtSubscope() {
    }

    func testWillCompleteCascadeBeginsAtSubscope() {
    }

    func testCompletionCascadeBeginsAtSuperscope() {
        let subject = CurrentValueSubject<TestEvent, Error>(.state)
        let publisher = subject.handleEvents { subscription in
        } receiveOutput: { event in
        } receiveCompletion: { completion in
        } receiveCancel: {
        } receiveRequest: { request in
        }.eraseToAnyPublisher()
    }

    func testCancelCascadeBeginsAtSuperscope() {
        let subject = CurrentValueSubject<TestEvent, Error>(.state)
        let publisher = subject.handleEvents { subscription in
        } receiveOutput: { event in
        } receiveCompletion: { completion in
        } receiveCancel: {
        } receiveRequest: { request in
        }.eraseToAnyPublisher()
    }


}

enum TestEvent {
    case state
}

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

extension Scope {
    var isSyncActive: Bool {
        var isSyncActive = false
        isActivePublisher.sink {
            isSyncActive = $0
        }.store(in: testBag)
        return isSyncActive
    }
}

final class ScopeEventReporter: Scope {

    var willStartCount = 0
    var willStopCount = 0
    var willEndCount = 0

    private let eventPublisher: AnyPublisher<TestEvent, Error>

    required init(
        eventPublisher: AnyPublisher<TestEvent, Error> = Empty<TestEvent, Error>().eraseToAnyPublisher()
    ) {
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

final class LifecycleCallbackScope: Scope {

    private let start: (() -> ())?
    private let stop: (() -> ())?
    private let end: (() -> ())?

    init(
        start: (() -> ())? = nil,
        stop:  (() -> ())? = nil,
        end:  (() -> ())? = nil
    ) {
        self.start = start
        self.stop = stop
        self.end = end
    }

    override func willStart() -> CancelBag {
        start()
        return CancelBag()
    }

    override func willStop() {
        stop()
    }

    override func willEnd() {
        end()
    }
}
