import Combine
import Foundation
import ScopeKit
import UIKit

class AppScope: Scope {

    private let window: UIWindow

    init(window: UIWindow) {
        self.window = window
        super.init()
    }

    override func willAttach() {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white
        window.rootViewController = viewController
        window.makeKeyAndVisible()
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        
    }

    override func didDeactivate() {

    }

    override func didDetach() {

    }
}
