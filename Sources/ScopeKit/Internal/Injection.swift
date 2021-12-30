import Combine
import Foundation

class Injection {
    #if DEBUG
    static var shared: InjectionProvider {
        currentProvider.value
    }
    private static var currentProvider = CurrentValueSubject<InjectionProvider, Never>(ReleaseInjectionProvider())
    static func with(provider: InjectionProvider, for block: () -> ()) {
        let oldProvider = currentProvider.value
        defer { currentProvider.value = oldProvider }
        currentProvider.value = provider
        block()
    }
    #else
    static let shared: InjectionProvider = ReleaseInjectionProvider()
    #endif
}

protocol InjectionProvider {
    func assert(_ condition: @autoclosure () -> Bool, _ message: String)
}

struct ReleaseInjectionProvider: InjectionProvider {
    func assert(_ condition: @autoclosure () -> Bool, _ message: String) {
        Swift.assert(condition(), message)
    }
}


