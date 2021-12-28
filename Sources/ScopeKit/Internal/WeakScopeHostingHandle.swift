import Foundation

struct WeakScopeHostingHandle {

    private let weakProvider: () -> AnyScopeHosting?

    init(weakProvider: @escaping () -> AnyScopeHosting?) {
        self.weakProvider = weakProvider
    }

    var value: AnyScopeHosting? {
        weakProvider()
    }
}

