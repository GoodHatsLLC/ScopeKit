import Foundation
import XCTest
@testable import ScopeKit

final class BehaviorTestRunner {

    let behaviorBuilder: () -> Behavior
    let lifecycleCallbackBehaviorBuilder: () -> LifecycleCallbackBehavior
    let root = RootScope()

    init(
        behaviorBuilder: @escaping () -> Behavior,
        lifecycleCallbackBehaviorBuilder: @escaping () -> LifecycleCallbackBehavior
    ) {
        self.behaviorBuilder = behaviorBuilder
        self.lifecycleCallbackBehaviorBuilder = lifecycleCallbackBehaviorBuilder
    }

    // MARK: - Retain behavior

    func test_noRetain_onInit() {
        weak var weakBehavior: Behavior? = nil
        autoreleasepool {
            let strongScope = self.behaviorBuilder()
            weakBehavior = strongScope
            XCTAssertNotNil(weakBehavior)
        }
        XCTAssertNil(weakBehavior)
    }

    func test_noRelease_whenAttached() {
        weak var weakBehavior: Behavior? = nil
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
        weak var weakBehavior: Behavior? = nil
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
        weak var weakBehavior: Behavior? = nil
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
        weak var weakBehavior: Behavior? = nil
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
        let root2 = RootScope()
        let behavior = self.lifecycleCallbackBehaviorBuilder()
        var didStop = false
        behavior.didDeactivateCallback = { didStop = true }
        behavior.attach(to: root)
        XCTAssertFalse(didStop)
        behavior.attach(to: root2)
        XCTAssertFalse(didStop)
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
