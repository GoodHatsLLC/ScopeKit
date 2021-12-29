import Combine
import Foundation

public protocol ScopedBehavior {
    var state: ActivityState { get }
    @discardableResult func attach(to host: AnyScopeHosting) -> Future<(), AttachmentError>
    @discardableResult func detach() -> Future<(), AttachmentError>
    func eraseToAnyScopedBehavior() -> AnyScopedBehavior
}
