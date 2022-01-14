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
    private let pastelBehavior = PastePublisherBehavior()

    init(
        listener: LoggedInScopeListener,
        window: UIWindow,
        tokenPublisher: AnyPublisher<AuthenticationToken, Never>
    ) {
        self.listener = listener
        self.tokenPublisher = tokenPublisher
        self.window = window
        super.init()
        pastelBehavior.attach(to: self)
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        let viewController = LoggedInViewController(listener: self)
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        pastelBehavior.pastelPublisher
            .map { Optional($0) }
            .assign(to: \.color, on: viewController)
            .store(in: &cancellables)
    }

}

extension LoggedInScope: LoggedInViewControllerListener {
    func requestLogout() {
        listener?.requestLogout()
    }
}
