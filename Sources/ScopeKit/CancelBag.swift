import Combine
import Foundation

public class CancelBag {
    var cancellables: Set<AnyCancellable>

    required public init<C: Collection>(_ cancellables: C) where C.Element == AnyCancellable {
        self.cancellables = Set(cancellables)
    }

    convenience public init(_ cancellables: AnyCancellable...) {
        self.init(cancellables)
    }

    convenience public init(@CancelBagBuilder _ builder: () -> [AnyCancellable]) {
        self.init(Set(builder()))
    }

    func release() -> [AnyCancellable] {
        defer { cancellables.removeAll() }
        return cancellables.map { $0 }
    }

    deinit {
        cancel()
    }
}

@resultBuilder
public struct CancelBagBuilder {
    public static func buildBlock(_ baggable: Cancelling...) -> [AnyCancellable] {
        baggable.flatMap { $0.asAnyCancellables() }
    }
    public static func buildArray(_ baggable: [Cancelling]) -> [AnyCancellable] {
        baggable.flatMap { $0.asAnyCancellables() }
    }
    public static func buildOptional(_ baggable: Cancelling?) -> [AnyCancellable] {
        baggable.map { $0.asAnyCancellables().map{ $0 } } ?? []
    }
}


// MARK: Cancellable
extension CancelBag: Cancellable {
    public func cancel() {
        // Cancel all work owned here.
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

// MARK: Extend AnyCancellable for storage in CancelBags
public extension AnyCancellable {
    func store(in scope: CancelBag) {
        store(in: &scope.cancellables)
    }
}

// MARK: CancelBag Merging
public extension CancelBag {
    func store(in scope: CancelBag) {
        scope.cancellables.formUnion(cancellables)
        cancellables.removeAll()
    }
}
