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
    private let pastelBehavior = PastelPublisherBehavior()

    init(listener: LoggedInScopeListener,
         window: UIWindow,
         initialToken: AuthenticationToken,
         tokenUpdateSubject: AnySubject<AuthenticationToken?, Never>
    ) {
        self.listener = listener
        self.window = window

        super.init()

        TokenRefreshBehavior(
            token: initialToken,
            refreshTokenSubject: tokenUpdateSubject
        ).attach(to: self)

        pastelBehavior.attach(to: self)

        AnonymousBehavior { cancellables in
            var count = 0
            Timer
                .publish(every: 60, on: .main, in: .default)
                .autoconnect()
                .sink { _ in
                    count += 1
                    debugPrint("🎉 Wow! You have been logged in for \(count) minute\(count > 1 ? "s" : "").")
                }
                .store(in: &cancellables)
        }.attach(to: self)
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
