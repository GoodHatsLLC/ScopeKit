import Combine
import Foundation
import ScopeKit
import UIKit

final class AppScope: Scope {

    private let window: UIWindow
    private let authTokenSubject = CurrentValueSubject<AuthenticationToken?, Never>(nil)

    private var loginStateScope: Scope? = nil

    init(window: UIWindow) {
        self.window = window
        super.init()
        let tokenSubject = authTokenSubject.eraseToAnySubject()
        TokenRefreshBehavior(tokenSubject: tokenSubject)
            .attach(to: self)
        TokenPersistenceBehavior(tokenSubject: tokenSubject)
            .attach(to: self)
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        let loggedInTokenPublisher = tokenPublisher
            .compactMap { $0 }
            .eraseToAnyPublisher()

        let loginStatePublisher = tokenPublisher
            .map {
                $0 != nil ? LoginState.loggedIn : LoginState.loggedOut
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

    var tokenPublisher: AnyPublisher<AuthenticationToken?, Never> {
        authTokenSubject.eraseToAnyPublisher()
    }

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
        authTokenSubject.send(token)
    }
}

extension AppScope: LoggedInScopeListener {
    func requestLogout() {
        authTokenSubject.send(nil)
    }
}
