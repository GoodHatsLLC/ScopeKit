import Foundation

protocol ScopedBehaviorInternal {
    var underlying: AnyObject { get }
    func willDetach(from host: AnyScopeHosting)
    func didAttach(to host: AnyScopeHosting)
}
