import Combine
import XCTest
@testable import ScopeKit

final class CancelBagTests: XCTestCase {

    private var cancelCount = 0

    override func setUp() {
        cancelCount = 0
    }

    override func tearDown() {
    }

    func incrementingCancellable() -> AnyCancellable {
        AnyCancellable {
            self.cancelCount += 1
        }
    }

    func cancelBagAsCancelling() -> Cancelling {
        CancelBag {
            incrementingCancellable()
        }
    }


    func testCreationSingle() {
        let bag = CancelBag(incrementingCancellable()) // 1
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 1)
    }

    func testCreationArray() {
        let bag = CancelBag([incrementingCancellable(), // 1
                             incrementingCancellable(), // 2
                             incrementingCancellable()]) // 3
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 3)
    }

    func testCreationVariadic() {
        let bag = CancelBag(incrementingCancellable(), // 1
                            incrementingCancellable(), // 2
                            incrementingCancellable()) // 3
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 3)
    }

    func testCreationBuilderVariadic() {
        let bag = CancelBag {
            incrementingCancellable() // 1
            incrementingCancellable() // 2
            incrementingCancellable() // 3
        }
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 3)
    }

    func testNestedCancelBags() {
        let bag = CancelBag {
            incrementingCancellable() // 1
            CancelBag {
                incrementingCancellable() // 2
            }
            CancelBag {
                incrementingCancellable() // 3
            }
        }
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 3)
    }

    func testCreationBuilderIfStatements() {
        let moreThanTwo = false
        let bag = CancelBag {
            incrementingCancellable() // 1
            incrementingCancellable() // 2
            if moreThanTwo {
                incrementingCancellable()
            }
        }
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 2)
    }

    func testUsingCancellingProtocolDirectly() {
        let bag = CancelBag {
            cancelBagAsCancelling() // 1
            cancelBagAsCancelling() // 2
            CancelBag {
                cancelBagAsCancelling() // 3
            }
        }
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 3)
    }

    func testVariadicMess() {
        let moreThanTwo = true
        let moreThanNine = false
        let aCancellable = incrementingCancellable() // 1
        let bag = CancelBag {
            [incrementingCancellable(), // 2
             incrementingCancellable()] // 3
            if moreThanTwo {
                incrementingCancellable() // 4
            }
            Set([incrementingCancellable(), // 5
                 incrementingCancellable()]) // 6
            aCancellable
            CancelBag {
                incrementingCancellable() // 7
                CancelBag {
                    incrementingCancellable() // 8
                    CancelBag {
                        incrementingCancellable() // 9
                    }
                }
            }
            if moreThanNine {
                incrementingCancellable()
            }
        }
        XCTAssertEqual(cancelCount, 0)
        bag.cancel()
        XCTAssertEqual(cancelCount, 9)
    }

    func testCancelBagOwnershipTransfer() {
        let bag1 = CancelBag {
            incrementingCancellable()
        }
        let bag2 = CancelBag {
            bag1
        }
        XCTAssertEqual(cancelCount, 0)
        bag1.cancel()
        XCTAssertEqual(cancelCount, 0)
        bag2.cancel()
        XCTAssertEqual(cancelCount, 1)
    }

    func testOwnershipReleaseToAnyCancellable() {
        let bag = CancelBag {
            incrementingCancellable()
        }
        XCTAssertEqual(cancelCount, 0)
        let cancellables = bag.asAnyCancellables()
        XCTAssertEqual(cancelCount, 0)
        cancellables.forEach { $0.cancel() }
        XCTAssertEqual(cancelCount, 1)
    }

}


