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
        autoreleasepool {
            let host = ScopeHost()
            weakHost = host
            let scope = Scope()
            scope.attach(to: host)
        }
        XCTAssertNil(weakHost)
    }

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

    func test_cancellableCalled_onDetach() {
        let scope = TestCancellableCalledScope()
        scope.attach(to: host)
        XCTAssertFalse(scope.cancellableCalled)
        scope.detach()
        XCTAssertTrue(scope.cancellableCalled)
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

final class TestCancellableCalledScope: Scope {
    var cancellableCalled: Bool = false
    override func willStart(cancellables: inout Set<AnyCancellable>) {
        AnyCancellable {
            self.cancellableCalled = true
        }.store(in: &cancellables)
    }
}
