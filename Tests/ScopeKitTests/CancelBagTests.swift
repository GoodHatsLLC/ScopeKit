import Combine
import XCTest
@testable import ScopeKit

final class CancelBagTests: XCTestCase {


    override func setUp() {
    }

    override func tearDown() {
    }

    func testCreationSingle() {
        _ = CancelBag(AnyCancellable({}))
    }

    func testCreationArray() {
        _ = CancelBag([AnyCancellable({}),
                       AnyCancellable({}),
                       AnyCancellable({})])
    }

    func testCreationVariadic() {
        _ = CancelBag(AnyCancellable({}),
                      AnyCancellable({}),
                      AnyCancellable({}))
    }

    func testCreationBuilderVariadic() {
        _ = CancelBag {
            AnyCancellable({})
            CancelBag {
                AnyCancellable({})
                AnyCancellable({})
            }
            CancelBag()
        }
    }

}
