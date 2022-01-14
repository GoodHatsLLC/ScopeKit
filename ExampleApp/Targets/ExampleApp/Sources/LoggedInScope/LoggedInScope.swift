import Combine
import Foundation
import ScopeKit
import UIKit

protocol LoggedInScopeListener: AnyObject {
    func requestLogout()
}

final class LoggedInScope: Scope {

    private weak var listener: LoggedInScopeListener?
    private let window: UIWindow
    private let tokenPublisher: AnyPublisher<AuthenticationToken, Never>

    init(
        listener: LoggedInScopeListener,
        window: UIWindow,
        tokenPublisher: AnyPublisher<AuthenticationToken, Never>
    ) {
        self.listener = listener
        self.tokenPublisher = tokenPublisher
        self.window = window
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        window.rootViewController = LoggedInViewController(listener: self)
        window.makeKeyAndVisible()
    }

}

extension LoggedInScope: LoggedInViewControllerListener {
    func requestLogout() {
        listener?.requestLogout()
    }
}
