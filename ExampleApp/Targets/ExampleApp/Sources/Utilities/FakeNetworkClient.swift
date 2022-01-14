import Combine
import Foundation

class FakeNetworkClient {

    struct FakeCredentials {
        static let username = "user"
        static let password = "password"
    }

    private static let gracePeriod = 100.0

    enum NetworkClientError: Error {
        case authenticationError
        case tokenRefreshError
    }

    func authenticate(username: String, password: String) -> Deferred<Future<AuthenticationToken, NetworkClientError>> {
        Deferred {
            Future { promise in
                if username == FakeCredentials.username &&
                    password == FakeCredentials.password {
                    promise(.success(AuthenticationToken.fakeToken))
                } else {
                    promise(.failure(.authenticationError))
                }
            }
        }
    }

    func refresh(token: AuthenticationToken) -> Deferred<Future<AuthenticationToken, NetworkClientError>> {
        Deferred {
            Future { promise in
                if Date().timeIntervalSince(token.grantDate) < (token.grantDuration + FakeNetworkClient.gracePeriod) {
                    promise(.success(AuthenticationToken.fakeToken))
                } else {
                    promise(.failure(.tokenRefreshError))
                }
            }
        }
    }
}
