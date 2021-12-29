import Combine
import XCTest
import ScopeKit

final class ScopeTests: XCTestCase {

    static var runner = {
        BehaviorTestRunner(
            behaviorBuilder: { Scope() },
            lifecycleCallbackBehaviorBuilder: { LifecycleCallbackScope() }
        )
    }

    var root: RootScope!

    override func setUp() {
        root = RootScope()
    }

    override func tearDown() {
        root = nil
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

    func test_noRetain_betweenUnreferencedAttachedScopes() {
        weak var weakHost: RootScope? = nil
        weak var weakScope: Scope? = nil
        autoreleasepool {
            let host = RootScope()
            weakHost = host
            let scope = Scope()
            weakScope = scope
            scope.attach(to: host)
            XCTAssertNotNil(weakHost)
            XCTAssertNotNil(weakScope)
        }
        XCTAssertNil(weakHost)
        XCTAssertNil(weakScope)
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

    // MARK: - Attachment cascading behavior

    func test_scopeAttachmentCascades_onAttach() {
        let zero = Scope()
        let one = Scope()
        one.attach(to: zero)
        let two = Scope()
        two.attach(to: one)
        let three = Scope()
        three.attach(to: two)
        let test = LifecycleCallbackScope()
        var isActive = false
        test.didStopCallback = { isActive = false }
        test.willStartCallback = { isActive = true }
        test.attach(to: three)
        XCTAssertFalse(isActive)
        zero.attach(to: root)
        XCTAssertTrue(isActive)
    }

    func test_scopeAttachmentCascades_onDetach() {
        let zero = Scope()
        zero.attach(to: root)
        let one = Scope()
        one.attach(to: zero)
        let two = Scope()
        two.attach(to: one)
        let three = Scope()
        three.attach(to: two)
        let test = LifecycleCallbackScope()
        var isActive = false
        test.didStopCallback = { isActive = false }
        test.willStartCallback = { isActive = true }
        test.attach(to: three)
        XCTAssertTrue(isActive)
        zero.detach()
        XCTAssertFalse(isActive)
    }

    // MARK: - External cancellable behavior

    func test_externalCancellable_stopsImmediatelyWhenUnattached() {
        let scope = Scope()
        var cancelCalled = false
        let cancellable = AnyCancellable {
            cancelCalled = true
        }
        XCTAssertFalse(cancelCalled)
        cancellable.store(in: &scope.storeWhileActive.cancellables)
        XCTAssertTrue(cancelCalled)
    }

    func test_externalCancellable_isNotStoppedWhenAttached() {
        let scope = Scope()
        scope.attach(to: root)
        var cancelCalled = false
        let cancellable = AnyCancellable {
            cancelCalled = true
        }
        cancellable.store(in: &scope.storeWhileActive.cancellables)
        XCTAssertFalse(cancelCalled)
    }

    func test_externalCancellable_stopsWhenDetached() {
        let scope = Scope()
        scope.attach(to: root)
        var cancelCalled = false
        let cancellable = AnyCancellable {
            cancelCalled = true
        }
        cancellable.store(in: &scope.storeWhileActive.cancellables)
        XCTAssertFalse(cancelCalled)
        scope.detach()
        XCTAssertTrue(cancelCalled)
    }

}

open class LifecycleCallbackScope: LifecycleCallbackBehavior {

    override open func willStart(cancellables: inout Set<AnyCancellable>) {
        willStartCallback?()
        AnyCancellable { [weak self] in
            guard let self = self else { return }
            self.cancelCallback?()
        }.store(in: &cancellables)
    }

    override open func didStop() {
        didStopCallback?()
    }
}
