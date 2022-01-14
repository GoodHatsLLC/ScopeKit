import Combine
import Foundation
import ScopeKit
import UIKit

final class AppScope: Scope {

    private let window: UIWindow
    private let tokenRefresher: TokenRefreshBehavior
    private let tokenPersister: TokenPersistenceBehavior
    private var loginStateScope: Scope? = nil

    init(window: UIWindow) {
        self.window = window
        tokenRefresher = TokenRefreshBehavior()
        tokenPersister = TokenPersistenceBehavior(
            tokenPublisher: tokenRefresher.currentTokenPublisher
        )
        // Only use cache if we find a non-nil value
        if let cachedToken = tokenPersister.cachedToken,
           cachedToken.isValid {
            tokenRefresher.resetToken(cachedToken)
        }
        super.init()
        tokenRefresher.attach(to: self)
        tokenPersister.attach(to: self)
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {

        let loggedInTokenPublisher = tokenRefresher.currentTokenPublisher
            .compactMap { $0 }
            .eraseToAnyPublisher()

        let loginStatePublisher = tokenRefresher.currentTokenPublisher
            .map { token -> LoginState in
                if let token = token,
                   token.isValid {
                    return LoginState.loggedIn
                } else {
                    return LoginState.loggedOut
                }
            }

        loginStatePublisher
            .removeDuplicates()
            .sink { [self] state in
                switch state {
                case .loggedOut:
                    attachLoginStateScope(
                        LoggedOutScope(
                            listener: self,
                            window: window
                        )
                    )
                case .loggedIn:
                    attachLoginStateScope(
                        LoggedInScope(
                            listener: self,
                            window: window,
                            tokenPublisher: loggedInTokenPublisher
                        )
                    )
                }
            }
            .store(in: &cancellables)
    }
}

private enum LoginState {
    case loggedIn
    case loggedOut
}

private extension AppScope {

    func removeCurrentLogInStateScopeIfNeeded() {
        if let current = loginStateScope {
            current.detach()
            loginStateScope = nil
        }
    }

    func attachLoginStateScope(_ scope: Scope) {
        removeCurrentLogInStateScopeIfNeeded()
        scope.attach(to: self)
        loginStateScope = scope
    }
}

extension AppScope: LoggedOutScopeListener {
    func login(token: AuthenticationToken) {
        tokenRefresher.resetToken(token)
    }
}

extension AppScope: LoggedInScopeListener {
    func requestLogout() {
        tokenRefresher.resetToken(nil)
    }
}
