import Combine
import Foundation

public class CancelBag: Cancellable, Hashable {

    fileprivate var cancellables: Set<AnyCancellable>

    deinit {
        cancel()
    }

    required public init(cancellables: Set<AnyCancellable> = Set()) {
        self.cancellables = cancellables
    }

    convenience public init<C: Collection>(cancellables: C) where C.Element == AnyCancellable {
        self.init(cancellables: Set(cancellables))
    }

    convenience public init(@CancelBagBuilder _ builder: () -> [AnyCancellable]) {
        self.init(cancellables: Set(builder()))
    }
}

public extension CancelBag {
    func cancel() {
        // Cancel all work owned here.
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

@resultBuilder
public struct CancelBagBuilder {
    public static func buildBlock(_ bags: CancelBag...) -> [AnyCancellable] {
        bags.flatMap { $0.cancellables }
    }
    public static func buildArray(_ bags: [CancelBag]) -> [AnyCancellable] {
        bags.flatMap { $0.cancellables }
    }
    public static func buildOptional(_ bags: CancelBag?) -> [AnyCancellable] {
        bags.map { $0.cancellables.map{$0} } ?? []
    }
    public static func buildBlock(_ cancellables: AnyCancellable...) -> [AnyCancellable] {
        cancellables
    }
    public static func buildArray(_ cancellables: [AnyCancellable]) -> [AnyCancellable] {
        cancellables
    }
    public static func buildOptional(_ cancelleble: AnyCancellable?) -> [AnyCancellable] {
        cancelleble.map { [$0] } ?? []
    }
}

// MARK: CancelBag Merging
public extension CancelBag {
    // Add self to passed CancelBag as a subscope
    func store(in scope: CancelBag) {
        scope.cancellables.formUnion(cancellables)
        self.cancellables.removeAll()
    }
}

// MARK: Extend AnyCancellable for storage in CancelBags
public extension AnyCancellable {
    func store(in scope: CancelBag) {
        store(in: &scope.cancellables)
    }
}

// MARK: Equatable
public extension CancelBag {
    static func == (lhs: CancelBag, rhs: CancelBag) -> Bool {
        lhs.cancellables == rhs.cancellables
    }
}

// MARK: Hashable
public extension CancelBag {
    func hash(into hasher: inout Hasher) {
        hasher.combine(cancellables)
    }
}

// MARK: Preview helper
#if DEBUG
struct Debug {
    static var scope = CancelBag()
}
#endif
