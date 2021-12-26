import Foundation

struct Weak<T> where T: AnyObject {

    private weak var weakValue: T?

    init(_ value: T?) {
        self.weakValue = value
    }
    
    var value: T? {
        weakValue
    }
}
