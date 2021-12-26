import Foundation

struct Weak<T>: Equatable where T: AnyObject, T: Equatable {

    private weak var weakValue: T?

    init(_ value: T) {
        self.weakValue = value
    }

    var value: T? {
        weakValue
    }
}
