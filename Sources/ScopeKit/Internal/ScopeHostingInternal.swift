import Combine
import Foundation

protocol ScopeHostingInternal {
    var statePublisher: AnyPublisher<ActivityState, Never> { get }
    var underlying: AnyObject { get }
    var weakHandle: ErasedProvider<AnyScopeHosting?> { get }
    var ancestors: [AnyScopeHosting] { get }
}
