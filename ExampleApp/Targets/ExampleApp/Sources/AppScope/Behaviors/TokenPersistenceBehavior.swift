import Combine
import Foundation
import ScopeKit

final class TokenPersistenceBehavior: Behavior {

    var cachedToken: AuthenticationToken? {
        let token = AuthenticationToken.fetchFromDiskCache()
        debugPrint("retrieved: \(String(describing: token))")
        return token
    }

    private let inputPublisher: AnyPublisher<AuthenticationToken?, Never>

    init(tokenPublisher: AnyPublisher<AuthenticationToken?, Never>) {
        self.inputPublisher = tokenPublisher
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        inputPublisher
            .sink { optionalToken in
                if let token = optionalToken {
                    do {
                        try token.writeToDiskCache()
                        debugPrint("persisted token")
                    } catch {
                        debugPrint("error persisting token")
                    }
                } else {
                    AuthenticationToken.eraseDiskCache()
                }
            }
            .store(in: &cancellables)
    }
}
