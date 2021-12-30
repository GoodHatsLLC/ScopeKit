import Combine
import XCTest
import ScopeKit

final class BehaviorTests: XCTestCase {

    static var runner = {
        BehaviorTestRunner(
            behaviorBuilder: { Behavior() },
            lifecycleCallbackBehaviorBuilder: { LifecycleCallbackBehavior() }
        )
    }

    var root: RootScope!

    override func setUp() {
        root = RootScope()
    }

    override func tearDown() {
        root = nil
    }

    // MARK: - Thread check

    func test_assertMainThread_onLifecycleCalls() {
        Self.runner().test_assertMainThread_onLifecycleCalls()
    }

    // MARK: - Retain behavior

    func test_noRetain_onInit() {
        Self.runner().test_noRetain_onInit()
    }

    func test_noRelease_whenAttached() {
        Self.runner().test_noRelease_whenAttached()
    }

    func test_noRetain_onceDetached() {
        Self.runner().test_noRetain_onceDetached()
    }

    func test_noRetain_WhenRootIsUnreferenced() {
        Self.runner().test_noRetain_WhenRootIsUnreferenced()
    }

    func test_noRetain_byFormerParentOnReparent() {
        Self.runner().test_noRetain_byFormerParentOnReparent()
    }

    // MARK: - willStart/didStop

    func test_willStartCalled_onAttach() {
        Self.runner().test_willStartCalled_onAttach()
    }

    func test_didStopCalled_onDetach() {
        Self.runner().test_didStopCalled_onDetach()
    }

    func test_willStartCalled_onReattach() {
        Self.runner().test_willStartCalled_onReattach()
    }

    func test_didStopNotCalled_onReparent() {
        Self.runner().test_didStopNotCalled_onReparent()
    }

    // MARK: - Cancellable

    func test_cancellableCalled_onDetach() {
        Self.runner().test_cancellableCalled_onDetach()
    }
}

open class LifecycleCallbackBehavior: Behavior {

    var willAttachCallback: (() -> ())? = nil
    var willActivateCallback: (() -> ())? = nil
    var didDeactivateCallback: (() -> ())? = nil
    var didDetachCallback: (() -> ())? = nil
    var cancelCallback: (() -> ())? = nil

    override open func willAttach() {
        willAttachCallback?()
    }

    override open func willActivate(cancellables: inout Set<AnyCancellable>) {
        willActivateCallback?()
        AnyCancellable {
            self.cancelCallback?()
        }.store(in: &cancellables)
    }

    override open func didDeactivate() {
        didDeactivateCallback?()
    }

    override open func didDetach() {
        didDetachCallback?()
    }
}
