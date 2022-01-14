import Combine
import Foundation
import ScopeKit

final class TokenRefreshBehavior: Behavior {

    private let client = FakeNetworkClient()
    private let refreshTokenSubject: AnySubject<AuthenticationToken?, Never>
    private let lastTokenSubject = CurrentValueSubject<AuthenticationToken?, Never>(nil)

    init(token: AuthenticationToken, refreshTokenSubject: AnySubject<AuthenticationToken?, Never>) {
        self.refreshTokenSubject = refreshTokenSubject
        super.init()
        lastTokenSubject.send(token)
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        lastTokenSubject
            .compactMap { $0 }
            .map { token in
                Just(())
                    .delay(for: .seconds(token.grantDuration), scheduler: RunLoop.main)
                    .map { token }
                    .first()
            }
            .switchToLatest()
            .map { [self] token in
                client.refresh(token: token)
                    .handleEvents(
                        receiveCompletion: { completion in
                            switch completion {
                            case .failure(let error):
                                debugPrint("could not refresh token: \(error)")
                            case .finished:
                                debugPrint("token refreshed")
                            }
                        }
                    )
                    // map away the error and fail silently with nil.
                    .map { Optional($0) }
                    .replaceError(with: nil)
                    .compactMap { $0 }
            }
            .switchToLatest()
            .sink { [self] token in
                lastTokenSubject.send(token)
                refreshTokenSubject.send(token)
            }
            .store(in: &cancellables)
    }

}
