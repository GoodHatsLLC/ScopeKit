import Foundation
import XCTest
@testable import ScopeKit

final class BehaviorTestRunner {

    typealias ScopeType = ScopedBehavior & AnyObject

    let behaviorBuilder: () -> ScopeType
    let lifecycleCallbackBehaviorBuilder: () -> LifecycleCallbackBehaviorType
    let root = RootScope().eraseToAnyScopeHosting()

    init(
        behaviorBuilder: @escaping () -> ScopeType,
        lifecycleCallbackBehaviorBuilder: @escaping () -> LifecycleCallbackBehaviorType
    ) {
        self.behaviorBuilder = behaviorBuilder
        self.lifecycleCallbackBehaviorBuilder = lifecycleCallbackBehaviorBuilder
    }

    // MARK: - Lifecycle call order

    func test_lifecycleCalls_onAttach() {
        let testBehavior = lifecycleCallbackBehaviorBuilder()
        var hitCounter = 0
        let incremented = { () -> Int in hitCounter += 1; return hitCounter }
        testBehavior.willAttachCallback = { XCTAssertEqual(incremented(), 1) }
        testBehavior.willActivateCallback = { XCTAssertEqual(incremented(), 2) }
        testBehavior.cancelCallback = { XCTAssertEqual(incremented(), 3) }
        testBehavior.didDeactivateCallback = { XCTAssertEqual(incremented(), 4) }
        testBehavior.didDetachCallback = { XCTAssertEqual(incremented(), 5) }

        testBehavior.attach(to: root)

        testBehavior.detach()

        XCTAssertEqual(hitCounter, 5)
    }


    // MARK: - Thread check

    func test_assertMainThread_onLifecycleCalls() {
        let provider = TestInjectionProvider()
        XCTAssertEqual(provider.assertMessageSubject.value.count, 0)
        Injection.with(provider: provider) {
            let behavior = self.behaviorBuilder()
            _ = DispatchQueue.global().sync(flags: .barrier) {
                behavior.attach(to: self.root)
            }
        }
        XCTAssertGreaterThan(provider.assertMessageSubject.value.count, 0)
    }

    // MARK: - Retain behavior

    func test_noRetain_onInit() {
        weak var weakBehavior: ScopeType? = nil
        autoreleasepool {
            let strongScope = self.behaviorBuilder()
            weakBehavior = strongScope
            XCTAssertNotNil(weakBehavior)
        }
        XCTAssertNil(weakBehavior)
    }

    func test_noRelease_whenAttached() {
        weak var weakBehavior: ScopeType? = nil
        autoreleasepool {
            {
                let behavior = self.behaviorBuilder()
                weakBehavior = behavior
                behavior.attach(to: root)
            }()
        }
        XCTAssertNotNil(weakBehavior)
    }

    func test_noRetain_onceDetached() {
        weak var weakBehavior: ScopeType? = nil
        autoreleasepool {
            {
                let behavior = self.behaviorBuilder()
                weakBehavior = behavior
                behavior.attach(to: root)
            }()
            XCTAssertNotNil(weakBehavior)
            weakBehavior?.detach()
        }
        XCTAssertNil(weakBehavior)
    }

    func test_noRetain_WhenRootIsUnreferenced() {
        weak var weakHost: RootScope? = nil
        weak var weakBehavior: ScopeType? = nil
        autoreleasepool {
            let host = RootScope()
            weakHost = host
            let behavior = self.behaviorBuilder()
            weakBehavior = behavior
            behavior.attach(to: host)
            XCTAssertNotNil(weakHost)
            XCTAssertNotNil(weakBehavior)
        }
        XCTAssertNil(weakHost)
        XCTAssertNil(weakBehavior)
    }

    func test_noRetain_byFormerParentOnReparent() {
        let root2 = RootScope()
        weak var weakBehavior: ScopeType? = nil
        autoreleasepool {
            let behavior = self.behaviorBuilder()
            weakBehavior = behavior
            behavior.attach(to: root)
            behavior.attach(to: root2)
            behavior.detach()
        }
        XCTAssertNil(weakBehavior)
    }

    // MARK: - willStart/didDeactivate

    func test_willStartCalled_onAttach() {
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        var isActive = false
        behavior.didDeactivateCallback = { isActive = false }
        behavior.willActivateCallback = { isActive = true }
        XCTAssertFalse(isActive)
        behavior.attach(to: root)
        XCTAssertTrue(isActive)
    }

    func test_didStopCalled_onDetach() {
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        var isActive = false
        behavior.didDeactivateCallback = { isActive = false }
        behavior.willActivateCallback = { isActive = true }
        behavior.attach(to: root)
        XCTAssertTrue(isActive)
        behavior.detach()
        XCTAssertFalse(isActive)
    }

    func test_willStartCalled_onReattach() {
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        var isActive = false
        behavior.didDeactivateCallback = { isActive = false }
        behavior.willActivateCallback = { isActive = true }
        behavior.attach(to: root)
        behavior.detach()
        XCTAssertFalse(isActive)
        behavior.attach(to: root)
        XCTAssertTrue(isActive)
    }

    func test_didStopNotCalled_onReparent() {
        let root2 = RootScope().eraseToAnyScopeHosting()
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        var didStop = false
        behavior.didDeactivateCallback = { didStop = true }
        behavior.attach(to: root)
        XCTAssertFalse(didStop)
        behavior.attach(to: root2)
        XCTAssertFalse(didStop)
    }

    func test_attach_isIdempotent() {
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        behavior.attach(to: root)
        var effect = false
        behavior.willAttachCallback = { effect = true }
        behavior.willActivateCallback = { effect = true }
        behavior.didDeactivateCallback = { effect = true }
        behavior.didDetachCallback = { effect = true }
        behavior.cancelCallback = { effect = true }

        behavior.attach(to: root)
        XCTAssertFalse(effect)
    }

    func test_detach_isIdempotent() {
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        var effect = false
        behavior.willAttachCallback = { effect = true }
        behavior.willActivateCallback = { effect = true }
        behavior.didDeactivateCallback = { effect = true }
        behavior.didDetachCallback = { effect = true }
        behavior.cancelCallback = { effect = true }

        behavior.detach()
        XCTAssertFalse(effect)
    }

    // MARK: - Cancellable

    func test_cancellableCalled_onDetach() {
        var cancelCalled = false
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        behavior.cancelCallback = { cancelCalled = true }
        behavior.attach(to: root)
        XCTAssertFalse(cancelCalled)
        behavior.detach()
        XCTAssertTrue(cancelCalled)
    }
}
