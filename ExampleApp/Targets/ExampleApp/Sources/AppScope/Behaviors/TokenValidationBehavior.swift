import Combine
import Foundation
import ScopeKit

enum LoginState {
    case loggedIn(AuthenticationToken)
    case loggedOut
}

final class TokenValidationBehavior: Behavior {

    let loginStatePublisher: AnyPublisher<LoginState, Never>

    init(tokenPublisher: AnyPublisher<AuthenticationToken?, Never>) {
        loginStatePublisher = tokenPublisher
            .map { token -> LoginState in
                if let token = token,
                   token.isValid {
                    return LoginState.loggedIn(token)
                } else {
                    return LoginState.loggedOut
                }
            }
            .eraseToAnyPublisher()
    }
}
