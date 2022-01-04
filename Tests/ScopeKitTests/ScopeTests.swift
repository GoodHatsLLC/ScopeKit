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

    var cancellables: Set<AnyCancellable>!
    var root: RootScope!

    override func setUp() {
        root = RootScope()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        root = nil
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Behavior tests

    func test_scope_passesBehaviorTests() {
        Self.runner().test_lifecycleCalls_onAttach()
        Self.runner().test_assertMainThread_onLifecycleCalls()
        Self.runner().test_noRetain_onInit()
        Self.runner().test_noRelease_whenAttached()
        Self.runner().test_noRetain_onceDetached()
        Self.runner().test_noRetain_WhenRootIsUnreferenced()
        Self.runner().test_noRetain_byFormerParentOnReparent()
        Self.runner().test_willStartCalled_onAttach()
        Self.runner().test_didStopCalled_onDetach()
        Self.runner().test_willStartCalled_onReattach()
        Self.runner().test_didStopNotCalled_onReparent()
        Self.runner().test_attach_isIdempotent()
        Self.runner().test_detach_isIdempotent()
        Self.runner().test_cancellableCalled_onDetach()
    }

    func test_attachToSelf_fails() {
        let scope = LifecycleCallbackScope()
        var effect = false
        scope.willAttachCallback = { effect = true }
        scope.willActivateCallback = { effect = true }
        scope.didDeactivateCallback = { effect = true }
        scope.didDetachCallback = { effect = true }
        scope.cancelCallback = { effect = true }
        var didSink = false
        scope.attach(to: scope)
            .sink(
                receiveCompletion: { completion in
                    didSink = true
                    switch completion {
                    case .failure(let error):
                        XCTAssertEqual(error, AttachmentError.circularAttachment)
                    case .finished:
                        XCTFail()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        XCTAssert(didSink)
        XCTAssertFalse(effect)
    }

    func test_indirectCircularAttachment_fails() {
        let scope1 = LifecycleCallbackScope()
        let scope2 = LifecycleCallbackScope()
        scope2.attach(to: scope1)
        var effect = false
        scope1.willAttachCallback = { effect = true }
        scope1.willActivateCallback = { effect = true }
        scope1.didDeactivateCallback = { effect = true }
        scope1.didDetachCallback = { effect = true }
        scope1.cancelCallback = { effect = true }
        var didSink = false
        scope1.attach(to: scope2)
            .sink(
                receiveCompletion: { completion in
                    didSink = true
                    switch completion {
                    case .failure(let error):
                        XCTAssertEqual(error, AttachmentError.circularAttachment)
                    case .finished:
                        XCTFail()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        XCTAssert(didSink)
        XCTAssertFalse(effect)
    }

    // MARK: - Retain behavior

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
        test.didDeactivateCallback = { isActive = false }
        test.willActivateCallback = { isActive = true }
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
        test.didDeactivateCallback = { isActive = false }
        test.willActivateCallback = { isActive = true }
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

class LifecycleCallbackScope: Scope, LifecycleCallbackBehaviorType {

    var willAttachCallback: (() -> ())? = nil
    var willActivateCallback: (() -> ())? = nil
    var didDeactivateCallback: (() -> ())? = nil
    var didDetachCallback: (() -> ())? = nil
    var cancelCallback: (() -> ())? = nil

    override func willAttach() {
        willAttachCallback?()
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        willActivateCallback?()
        AnyCancellable {
            self.cancelCallback?()
        }.store(in: &cancellables)
    }

    override func didDeactivate() {
        didDeactivateCallback?()
    }

    override func didDetach() {
        didDetachCallback?()
    }
}
