import Combine
import Foundation
import ScopeKit
import UIKit

final class AppScope: Scope {

    private let window: UIWindow
    private let tokenSubject = CurrentValueSubject<AuthenticationToken?, Never>(nil)
    private let tokenPersister: TokenPersistenceBehavior
    private let tokenValidator: TokenValidationBehavior
    private var loginStatePublisher: AnyPublisher<LoginState, Never> {
        tokenValidator.loginStatePublisher.eraseToAnyPublisher()
    }
    private var loginStateScope: Scope? = nil

    init(window: UIWindow) {
        self.window = window

        tokenPersister = TokenPersistenceBehavior(
            tokenPublisher: tokenSubject.eraseToAnyPublisher()
        )

        tokenValidator = TokenValidationBehavior(
            tokenPublisher: tokenSubject.eraseToAnyPublisher()
        )

        // Only use cache if we find a non-nil value
        if let cachedToken = tokenPersister.cachedToken,
           cachedToken.isValid {
            tokenSubject.send(tokenPersister.cachedToken)
        }
        super.init()
        tokenPersister.attach(to: self)
        tokenValidator.attach(to: self)
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        loginStatePublisher
            .removeDuplicates { lhs, rhs in
                switch (lhs, rhs) {
                case (.loggedOut, .loggedOut),
                    (.loggedIn, .loggedIn):
                    return true
                default:
                    return false
                }
            }
            .sink { [self] state in
                switch state {
                case .loggedOut:
                    attachLoginStateScope(
                        LoggedOutScope(
                            listener: self,
                            window: window
                        )
                    )
                case .loggedIn(let token):
                    attachLoginStateScope(
                        LoggedInScope(
                            listener: self,
                            window: window,
                            initialToken: token,
                            tokenUpdateSubject: tokenSubject.eraseToAnySubject()
                        )
                    )
                }
            }
            .store(in: &cancellables)
    }
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
        tokenSubject.send(token)
    }
}

extension AppScope: LoggedInScopeListener {
    func requestLogout() {
        tokenSubject.send(nil)
    }
}
