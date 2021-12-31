import Foundation

struct ErasedProvider<T> {

    private let provider: () -> T

    init(provider: @escaping () -> T) {
        self.provider = provider
    }

    var value: T {
        provider()
    }
}

