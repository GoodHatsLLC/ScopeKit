import Combine
import Foundation
import ScopeKit

final class TokenPersistenceBehavior: Behavior {

    private let tokenSubject: AnySubject<AuthenticationToken?, Never>

    init(tokenSubject: AnySubject<AuthenticationToken?, Never>) {
        self.tokenSubject = tokenSubject
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        let optionalCachedToken = AuthenticationToken.fetchFromDiskCache()
        let optionalCachedTokenPublisher = Just(optionalCachedToken)

        // fetch initial token from cache
        optionalCachedTokenPublisher
            .compactMap { $0 }
            .sink { [self] token in
                tokenSubject.send(token)
            }
            .store(in: &cancellables)

        // write new tokens to cache
        tokenSubject
            .filter { newOptionalToken in
                // allow all if no initial cached token
                guard let cachedToken = optionalCachedToken else {
                    return true
                }

                // filter out the initial token
                return newOptionalToken != cachedToken
            }
            .removeDuplicates()
            .sink { optionalToken in
                if let token = optionalToken {
                    do {
                        try token.writeToDiskCache()
                    } catch {}
                } else {
                    AuthenticationToken.eraseDiskCache()
                }
            }
            .store(in: &cancellables)
    }
}
