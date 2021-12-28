import Combine
import Foundation

protocol ScopeHostingInternal {
    var statePublisher: AnyPublisher<ScopeState, Never> { get }
    var underlying: AnyObject { get }
    var weakHandle: WeakScopeHostingHandle { get }
}
