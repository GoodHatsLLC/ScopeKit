import Combine
import XCTest
import ScopeKit

final class ScopeTests: XCTestCase {

    var host: ScopeHost!

    override func setUp() {
        host = ScopeHost()
    }

    override func tearDown() {
        host = nil
    }

    // MARK: - Retain behavior

    func test_noRetain_onInit() {
        weak var weakScope: Scope? = nil
        autoreleasepool {
            let strongScope = Scope()
            weakScope = strongScope
            XCTAssertNotNil(weakScope)
        }
        XCTAssertNil(weakScope)
    }

    func test_noRelease_whenAttached() {
        weak var weakScope: Scope? = nil
        autoreleasepool {
            {
                let scope = Scope()
                weakScope = scope
                scope.attach(to: host)
            }()
        }
        XCTAssertNotNil(weakScope)
    }

    func test_noRetain_onceDetached() {
        weak var weakScope: Scope? = nil
        autoreleasepool {
            {
                let scope = Scope()
                weakScope = scope
                scope.attach(to: host)
            }()
            XCTAssertNotNil(weakScope)
            weakScope?.detach()
        }
        XCTAssertNil(weakScope)
    }

    func test_noRetain_betweenUnreferencedAttachedScopes() {
        weak var weakHost: ScopeHost? = nil
        weak var weakScope: Scope? = nil
        autoreleasepool {
            let host = ScopeHost()
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

    func test_noRetain_byFormerParentOnReparent() {
        let host2 = ScopeHost()
        weak var weakScope: Scope? = nil
        autoreleasepool {
            let scope = Scope()
            weakScope = scope
            scope.attach(to: host)
            scope.attach(to: host2)
            scope.detach()
        }
        XCTAssertNil(weakScope)
    }

    // MARK: - willStart/didStop

    func test_willStartCalled_onAttach() {
        let scope = TestIsActiveScope()
        XCTAssertFalse(scope.isActive)
        scope.attach(to: host)
        XCTAssertTrue(scope.isActive)
    }

    func test_didStopCalled_onDetach() {
        let scope = TestIsActiveScope()
        scope.attach(to: host)
        XCTAssertTrue(scope.isActive)
        scope.detach()
        XCTAssertFalse(scope.isActive)
    }

    func test_willStartCalled_onReattach() {
        let scope = TestIsActiveScope()
        scope.attach(to: host)
        scope.detach()
        XCTAssertFalse(scope.isActive)
        scope.attach(to: host)
        XCTAssertTrue(scope.isActive)
    }

    func test_didStopNotCalled_onReparent() {
        let host2 = ScopeHost()
        let scope = LifecycleCallbackScope()
        var didStop = false
        scope.didStopCallback = { didStop = true }
        scope.attach(to: host)
        XCTAssertFalse(didStop)
        scope.attach(to: host2)
        XCTAssertFalse(didStop)
    }

    // MARK: - Cancellable

    func test_cancellableCalled_onDetach() {
        let scope = TestCancellableCalledScope()
        scope.attach(to: host)
        XCTAssertFalse(scope.cancellableCalled)
        scope.detach()
        XCTAssertTrue(scope.cancellableCalled)
    }

    // MARK: - Attachment cascading behavior

    func test_scopeAttachmentCascades_onAttach() {
        let root = Scope()
        let one = Scope()
        one.attach(to: root)
        let two = Scope()
        two.attach(to: one)
        let three = Scope()
        three.attach(to: two)
        let test = TestIsActiveScope()
        test.attach(to: three)
        XCTAssertFalse(test.isActive)
        root.attach(to: host)
        XCTAssertTrue(test.isActive)
    }

    func test_scopeAttachmentCascades_onDetach() {
        let root = Scope()
        root.attach(to: host)
        let one = Scope()
        one.attach(to: root)
        let two = Scope()
        two.attach(to: one)
        let three = Scope()
        three.attach(to: two)
        let test = TestIsActiveScope()
        test.attach(to: three)
        XCTAssertTrue(test.isActive)
        root.detach()
        XCTAssertFalse(test.isActive)
    }

    // MARK: - External cancellable behavior

    func test_externalCancellable_stopsImmediatelyWhenUnattached() {
        let scope = Scope()
        var cancelCalled = false
        let cancellable = AnyCancellable {
            cancelCalled = true
        }
        XCTAssertFalse(cancelCalled)
        cancellable.store(in: &scope.whileActive)
        XCTAssertTrue(cancelCalled)
    }

    func test_externalCancellable_isNotStoppedWhenAttached() {
        let scope = Scope()
        scope.attach(to: host)
        var cancelCalled = false
        let cancellable = AnyCancellable {
            cancelCalled = true
        }
        cancellable.store(in: &scope.whileActive)
        XCTAssertFalse(cancelCalled)
    }

    func test_externalCancellable_stopsWhenDetached() {
        let scope = Scope()
        scope.attach(to: host)
        var cancelCalled = false
        let cancellable = AnyCancellable {
            cancelCalled = true
        }
        cancellable.store(in: &scope.whileActive)
        XCTAssertFalse(cancelCalled)
        scope.detach()
        XCTAssertTrue(cancelCalled)
    }

    func test_aThingThatShouldFail() {
        XCTAssertFalse(true)
    }

}

final class TestIsActiveScope: Scope {
    var isActive: Bool = false
    override func willStart(cancellables: inout Set<AnyCancellable>) {
        isActive = true
    }
    override func didStop() {
        isActive = false
    }
}

final class LifecycleCallbackScope: Scope {
    var willStartCallback: (() -> ())? = nil
    var didStopCallback: (() -> ())? = nil
    override func willStart(cancellables: inout Set<AnyCancellable>) {
        willStartCallback?()
    }
    override func didStop() {
        didStopCallback?()
    }
}

final class TestCancellableCalledScope: Scope {
    var cancellableCalled: Bool = false
    override func willStart(cancellables: inout Set<AnyCancellable>) {
        AnyCancellable {
            self.cancellableCalled = true
        }.store(in: &cancellables)
    }
}
