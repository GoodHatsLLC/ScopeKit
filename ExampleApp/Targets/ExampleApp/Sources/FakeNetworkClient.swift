import Combine
import Foundation

struct AuthenticationToken: Codable {

    static let fakeToken = AuthenticationToken(
        grantDate: Date(),
        grantDuration: 60*5
    )

    let grantDate: Date
    let grantDuration: TimeInterval
}

class FakeNetworkClient {

    struct FakeCredentials {
        static let username = "user"
        static let password = "password"
    }

    enum NetworkClientError: Error {
        case authenticationError
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
}
