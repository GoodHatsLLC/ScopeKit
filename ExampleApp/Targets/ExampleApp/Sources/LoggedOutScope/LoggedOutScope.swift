import Combine
import Foundation
import ScopeKit
import UIKit

protocol LoggedOutScopeListener: AnyObject {
    func login(token: AuthenticationToken)
}


final class LoggedOutScope: Scope {

    private weak var listener: LoggedOutScopeListener?
    private let window: UIWindow
    private let networkClient = FakeNetworkClient()
    
    init(listener: LoggedOutScopeListener, window: UIWindow) {
        self.window = window
        self.listener = listener
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        window.rootViewController = LoggedOutViewController(listener: self)
        window.makeKeyAndVisible()
    }

}

extension LoggedOutScope: LoggedOutViewControllerListener {
    func login(username: String, password: String) {
        networkClient
            .authenticate(username: username, password: password)
        
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [self] token in
                    listener?.login(token: token)
                }
            )
            .store(in: whileActiveReceiver)
    }
}
