import Combine
import XCTest
@testable import ScopeKit

final class DependencyKitTests: XCTestCase {

    private let root = ScopeRoot()

    override func setUp() {
    }

    override func tearDown() {
    }

    func testActivation() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(!scope.externalIsActiveSubject.value)
        scope.enable()
        XCTAssert(scope.externalIsActiveSubject.value)
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

    func testDetachmentUpdatesSubjects() {
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

    func testDetachmentTriggersReleaseOfChain() {
        var scope: Scope? = Scope()
        var subscopescope: Scope? = Scope()
        var descendantScope: Scope? = Scope()
        weak var weakScope = scope
        weak var weakSubscope = subscopescope
        weak var weakDescendantScope = descendantScope
        scope!.attach(to: root)
        subscopescope!.attach(to: scope!)
        weakDescendantScope!.attach(to: subscopescope!)
        scope = nil
        subscopescope = nil
        descendantScope = nil
        XCTAssertNotNil(weakScope)
        XCTAssertNotNil(weakSubscope)
        XCTAssertNotNil(weakDescendantScope)
        weakScope?.detach()
        XCTAssertNil(weakScope)
        XCTAssertNil(weakSubscope)
        XCTAssertNil(weakDescendantScope)
    }

    func testChangedSuperscopeRetains() {
        let root2 = ScopeRoot()
        var subscope: Scope? = Scope()
        weak var weakSubscope = subscope
        subscope!.attach(to: root)
        subscope = nil
        XCTAssertNotNil(weakSubscope)
        weakSubscope?.attach(to: root2)
        XCTAssertNotNil(weakSubscope)
    }

    func testNewSuperscopeOwnsLifecycle() {
        let newSuperscope = Scope()
        newSuperscope.attach(to: root)
        newSuperscope.enable()
        let subscope = ReportingScope()
        subscope.attach(to: root)
        subscope.enable()
        XCTAssertEqual(subscope.willStartCount, 1)
        XCTAssertEqual(subscope.willStopCount, 0)
        subscope.attach(to: newSuperscope)
        XCTAssertEqual(subscope.willStartCount, 1)
        XCTAssertEqual(subscope.willStopCount, 0)
        newSuperscope.disable()
        XCTAssertEqual(subscope.willStartCount, 1)
        XCTAssertEqual(subscope.willStopCount, 1)
    }

    func testNewSuperscopeRemovesPreviousSuperscopeChild() {
        let oldSuperscope = Scope()
        let subscope = Scope()
        let newSuperscope = Scope()
        oldSuperscope.attach(to: root)
        newSuperscope.attach(to: root)
        subscope.attach(to: oldSuperscope)
        XCTAssert(oldSuperscope.subscopesSubject.value.first === subscope)
        subscope.attach(to: newSuperscope)
        XCTAssertNil(oldSuperscope.subscopesSubject.value.first)
    }

    func testActivationUpdatesSubscope() {
        let scope = Scope()
        scope.attach(to: root)
        XCTAssert(!scope.externalIsActiveSubject.value)
        scope.enable()
        XCTAssert(scope.externalIsActiveSubject.value)
    }

    func testActivationUpdatesSubscopesRecursively() {
        let scope = Scope()
        let subscope = Scope()
        scope.attach(to: root)
        subscope.attach(to: scope)
        subscope.enable()
        XCTAssert(!subscope.externalIsActiveSubject.value)
        scope.enable()
        XCTAssert(subscope.externalIsActiveSubject.value)
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
                .map(\.externalIsActiveSubject.value)
                .reduce(false) { $0 || $1 }
        )
        scope.enable()
        XCTAssert(
            subscopes
                .map(\.externalIsActiveSubject.value)
                .reduce(true) { $0 && $1 }
        )
    }

    func testAttachmentToInactiveScopeDoesNotActivateScopes() {
        let scope = Scope()
        scope.attach(to: root)
        let subscope = Scope()
        subscope.enable()
        XCTAssert(!subscope.externalIsActiveSubject.value)
        subscope.attach(to: scope)
        XCTAssert(!subscope.externalIsActiveSubject.value)
    }

    func testAttachmentToActiveScopeActivatesSubscope() {
        let scope = Scope()
        scope.attach(to: root)
        scope.enable()
        let subscope = Scope()
        subscope.enable()
        XCTAssert(!subscope.externalIsActiveSubject.value)
        subscope.attach(to: scope)
        XCTAssert(subscope.externalIsActiveSubject.value)
    }

    func testDetachmentStopsScope() {
        let subscope = Scope()
        subscope.enable()
        subscope.attach(to: root)
        XCTAssert(subscope.externalIsActiveSubject.value)
        subscope.detach()
        XCTAssert(!subscope.externalIsActiveSubject.value)
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
        XCTAssert(!subscope.externalIsActiveSubject.value)
        superscope.attach(to: root)
        XCTAssert(subscope.externalIsActiveSubject.value)
        XCTAssert(superscopeStarted)
        XCTAssert(subscopeStarted)
    }

    func testWillStopCascadeBeginsAtSubscope() {
        var superscopeStopped = false
        var subscopeStopped = false
        let superscope = ReportingScope(stop: {
            XCTAssert(subscopeStopped)
            superscopeStopped = true
        })
        superscope.enable()
        let subscope = ReportingScope(stop: {
            XCTAssert(!superscopeStopped)
            subscopeStopped = true
        })
        subscope.attach(to: superscope)
        superscope.attach(to: root)
        subscope.enable()
        superscope.enable()

        XCTAssert(!superscopeStopped)
        XCTAssert(!subscopeStopped)
        XCTAssert(subscope.externalIsActiveSubject.value)
        superscope.disable()
        XCTAssert(!subscope.externalIsActiveSubject.value)
        XCTAssert(subscopeStopped)
        XCTAssert(superscopeStopped)
    }

}
