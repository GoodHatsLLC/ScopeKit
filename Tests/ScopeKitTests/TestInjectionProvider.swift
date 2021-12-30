import Combine
import Foundation
@testable import ScopeKit

class TestInjectionProvider: InjectionProvider {
    let assertMessageSubject = CurrentValueSubject<[String], Never>([])
    func assert(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertMessageSubject.value.append(message)
    }
}
