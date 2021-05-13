import Foundation

struct Weak<T: AnyObject> {
    private weak var held: T?
    init(_ held: T?) {
        self.held = held
    }
    func get() -> T? {
        held
    }
}
