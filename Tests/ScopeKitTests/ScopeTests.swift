import Combine
import XCTest
@testable import ScopeKit

extension Scope {
    var isSyncActive: Bool {
        var isSyncActive = false
        isActivePublisher.sink {
            isSyncActive = $0
        }.store(in: testBag)
        return isSyncActive
    }
}

private let testBag = CancelBag()

final class DependencyKitTests: XCTestCase {

    private let root = ScopeHost()

    override func setUp() {
    }

    override func tearDown() {
        testBag.cancel()
    }

    func testActivation() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(!scope.isSyncActive)
        scope.enable()
        XCTAssert(scope.isSyncActive)
    }

    func testAttachmentUpdatesSubjects() {
        let scope = Scope()
        XCTAssertNil(scope.superscopeSubject.value.get())
        XCTAssertNil(root.subscopesSubject.value.first)
        scope.attach(to: root)
        XCTAssert(scope.superscopeSubject.value.get() === root)
        XCTAssert(root.subscopesSubject.value.first === scope)
    }

    func testMultipleSubscopeAttatchmentAndOrdering() {
        let subscopes = [Scope(), Scope(), Scope()]
        XCTAssertEqual(root.subscopesSubject.value.count, 0)
        XCTAssert(
            subscopes
                .map(\.superscopeSubject.value)
                .allSatisfy { $0.get() === nil}
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
                .allSatisfy { $0.get() === root}
        )
    }

    func testDetatchmentUpdatesSubjects() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(scope.superscopeSubject.value.get() === root)
        XCTAssert(root.subscopesSubject.value.first === scope)
        scope.detach()
        XCTAssertNil(scope.superscopeSubject.value.get())
        XCTAssertNil(root.subscopesSubject.value.first)
    }

    func testAttachmentPreventsRelease() {
        var scope: Scope? = Scope()
        weak var weakSubscope = scope!
        scope?.attach(to: root)
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
        subscope!.attach(to: root)
        subscope = nil
        XCTAssertNotNil(weakSubscope)
        weakSubscope?.detach()
        XCTAssertNil(weakSubscope)
    }

    func testActivationUpdatesSubscope() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(!scope.isSyncActive)
        scope.enable()
        XCTAssert(scope.isSyncActive)
    }

    func testActivationUpdatesSubscopesRecursively() {
        let scope = Scope()
        let subscope = Scope()
        scope.attach(to: root)
        subscope.attach(to: scope)
        subscope.enable()
        XCTAssert(!subscope.isSyncActive)
        scope.enable()
        XCTAssert(subscope.isSyncActive)
    }

    func testActivationUpdatesMultipleSubscopes() {
        let scope = Scope()
        scope.attach(to: root)
        let subscopes = [Scope(), Scope(), Scope()]
        subscopes.forEach {
            $0.enable()
            $0.attach(to: scope)
        }
        XCTAssert(
            !subscopes
                .map(\.isSyncActive)
                .reduce(false) { $0 || $1 }
        )
        scope.enable()
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
        subscope.enable()
        XCTAssert(!subscope.isSyncActive)
        subscope.attach(to: scope)
        XCTAssert(!subscope.isSyncActive)
    }

    func testAttachmentToActiveScopeActivatesSubscope() {
        let scope = Scope()
        scope.attach(to: root)
        scope.enable()
        let subscope = Scope()
        subscope.enable()
        XCTAssert(!subscope.isSyncActive)
        subscope.attach(to: scope)
        XCTAssert(subscope.isSyncActive)
    }

    func testDetatchmentStopsScope() {
        let subscope = Scope()
        subscope.enable()
        subscope.attach(to: root)
        XCTAssert(subscope.isSyncActive)
        subscope.detach()
        XCTAssert(!subscope.isSyncActive)
    }

    func testStartCallsWillStart() {
        let scope = ReportingScope()
        scope.attach(to: root)
        XCTAssertEqual(scope.willStartCount, 0)
        scope.enable()
        XCTAssertEqual(scope.willStartCount, 1)
    }

    func testStopCallsWillStopOnlyIfPreviouslyStarted() {
        let scope = ReportingScope()
        scope.attach(to: root)
        scope.disable()
        XCTAssertEqual(scope.willStopCount, 0)
        scope.enable()
        scope.disable()
        XCTAssertEqual(scope.willStopCount, 1)
    }

    func testEndCallsWillEnd() {
        let scope = ReportingScope()
        scope.attach(to: root)
        XCTAssertEqual(scope.willEndCount, 0)
        scope.dispose()
        XCTAssertEqual(scope.willEndCount, 1)
    }

    func testStartAfterEndDoesNotFire() {
        let scope = ReportingScope()
        scope.attach(to: root)
        scope.dispose()
        scope.enable()
        XCTAssertEqual(scope.willStartCount, 0)
    }

    func testStartTriggersSubscription() {
        let rep = reportingPublisher(ReportingTestEvent.state)
        let scope = ReportingScope(eventPublisher: rep.publisher)
        scope.attach(to: root)
        XCTAssertEqual(rep.subscriptionCallCount(), 0)
        scope.enable()
        XCTAssertEqual(rep.subscriptionCallCount(), 1)
    }

    func testStartTriggersRequest() {
        let rep = reportingPublisher(ReportingTestEvent.state)
        let scope = ReportingScope(eventPublisher: rep.publisher)
        scope.attach(to: root)
        XCTAssertEqual(rep.requestCallCount(), 0)
        scope.enable()
        XCTAssertEqual(rep.requestCallCount(), 1)
    }

    func testStartAllowsEvent() {
        let rep = reportingPublisher(ReportingTestEvent.state)
        let scope = ReportingScope(eventPublisher: rep.publisher)
        scope.attach(to: root)
        XCTAssertEqual(rep.eventCallCount(), 0)
        scope.enable()
        XCTAssertEqual(rep.eventCallCount(), 1)
    }

    func testStopTriggersCancel() {
        let rep = reportingPublisher(ReportingTestEvent.state)
        let scope = ReportingScope(eventPublisher: rep.publisher)
        scope.attach(to: root)
        scope.enable()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.disable()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

    func testEndTriggersCancel() {
        let rep = reportingPublisher(ReportingTestEvent.state)
        let scope = ReportingScope(eventPublisher: rep.publisher)
        scope.attach(to: root)
        scope.enable()
        XCTAssertEqual(rep.cancelCallCount(), 0)
        scope.dispose()
        XCTAssertEqual(rep.cancelCallCount(), 1)
    }

    func testAttachInsufficientToStart() {
        let scope = ReportingScope()
        scope.attach(to: root)
        XCTAssertEqual(scope.willStartCount, 0)
    }

    func testStartedAttachStarts() {
        let scope = ReportingScope()
        scope.enable()
        XCTAssertEqual(scope.willStartCount, 0)
        scope.attach(to: root)
        XCTAssertEqual(scope.willStartCount, 1)
    }


    func testWillStartCascadeBeginsAtSuperscope() {
        var superscopeStarted = false
        var subscopeStarted = false
        let superscope = ReportingScope(start: {
            XCTAssert(!subscopeStarted)
            superscopeStarted = true
        })
        superscope.enable()
        let subscope = ReportingScope(start: {
            XCTAssert(superscopeStarted)
            subscopeStarted = true
        })
        subscope.enable()
        subscope.attach(to: superscope)
        XCTAssert(!superscopeStarted)
        XCTAssert(!subscopeStarted)
        XCTAssert(!subscope.isSyncActive)
        superscope.attach(to: root)
        XCTAssert(subscope.isSyncActive)
        XCTAssert(superscopeStarted)
        XCTAssert(subscopeStarted)
    }

    func testWillSuspendCascadeBeginsAtSubscope() {
    }

    func testWillCompleteCascadeBeginsAtSubscope() {
    }

    func testCompletionCascadeBeginsAtSuperscope() {
        let subject = CurrentValueSubject<ReportingTestEvent, Error>(.state)
        let publisher = subject.handleEvents { subscription in
        } receiveOutput: { event in
        } receiveCompletion: { completion in
        } receiveCancel: {
        } receiveRequest: { request in
        }.eraseToAnyPublisher()
    }

    func testCancelCascadeBeginsAtSuperscope() {
        let subject = CurrentValueSubject<ReportingTestEvent, Error>(.state)
        let publisher = subject.handleEvents { subscription in
        } receiveOutput: { event in
        } receiveCompletion: { completion in
        } receiveCancel: {
        } receiveRequest: { request in
        }.eraseToAnyPublisher()
    }


}
