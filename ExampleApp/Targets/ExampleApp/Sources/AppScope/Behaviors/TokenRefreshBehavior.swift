import Combine
import Foundation
import ScopeKit

final class TokenRefreshBehavior: Behavior {

    private let tokenSubject: AnySubject<AuthenticationToken?, Never>
    private let client = FakeNetworkClient()

    init(tokenSubject: AnySubject<AuthenticationToken?, Never>) {
        self.tokenSubject = tokenSubject
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        tokenSubject
            .compactMap { $0 }
            .flatMap { token in
                Just(())
                    .delay(for: .seconds(token.grantDuration), scheduler: RunLoop.main)
                    .map { token }
            }
            .flatMap { [self] token in
                client.refresh(token: token)
                    // map away the error and fail silently.
                    .map { Optional($0) }
                    .replaceError(with: nil)
                    .compactMap { $0 }
            }
            .sink { [self] token in
                tokenSubject.send(token)
            }
            .store(in: &cancellables)
    }

}
