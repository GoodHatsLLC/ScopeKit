import Foundation
import UIKit

protocol LoggedOutViewControllerListener: AnyObject {
    func login(username: String, password: String)
}

final class LoggedOutView: UIView {

    lazy var loginButton: UIButton = {
        let button = UIButton(configuration: .borderedTinted(), primaryAction: nil)
        button.setTitle("Log In", for: .normal)
        return button
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = .white
        addSubview(loginButton)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        loginButton.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class LoggedOutViewController: UIViewController {

    private lazy var thisView = LoggedOutView()
    private weak var listener: LoggedOutViewControllerListener?

    init(listener: LoggedOutViewControllerListener) {
        self.listener = listener
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = thisView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        thisView.loginButton.addAction(
            UIAction { [weak self] _ in
                self?.listener?.login(username: "user", password: "password")
            },
            for: .touchUpInside
        )
    }

}
