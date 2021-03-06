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

        // Only use the cache if we find a non-nil value
        if let cachedToken = tokenPersister.cachedToken,
           cachedToken.isValid {
            tokenSubject.send(tokenPersister.cachedToken)
        }
        super.init()

        // by attaching once in init we avoid having to
        // balance a removal or avoid a duplicate attach.
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
                    // we attach logged-in and logged out dynamically.
                    // we track the previously attached scope and remove it.
                    // `loginStateScope`
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

    // It would be nice to have helpers for common
    // attachment types/combinations.
    // i.e. MutuallyExclusive, enum identified, queue.
    func attachLoginStateScope(_ scope: Scope) {
        removeCurrentLogInStateScopeIfNeeded()
        scope.attach(to: self)
        loginStateScope = scope
    }
}

// A listener patterns works fine for inter-scope
// communication. Nothing precludes something fancier, though.
// We could standardise a system but it's not clear there's
// much to gain from it.
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
