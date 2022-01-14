import Foundation
import UIKit

protocol LoggedInViewControllerListener: AnyObject {
    func requestLogout()
}

final class LoggedInView: UIView {

    lazy var logoutButton: UIButton = {
        let button = UIButton(configuration: .borderedTinted(), primaryAction: nil)
        button.setTitle("Log out", for: .normal)
        return button
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = .white
        addSubview(logoutButton)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        logoutButton.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class LoggedInViewController: UIViewController {

    private weak var listener: LoggedInViewControllerListener?

    init(listener: LoggedInViewControllerListener) {
        self.listener = listener
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var thisView = LoggedInView()

    override func loadView() {
        view = thisView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        thisView.logoutButton.addAction(
            UIAction { [weak self] _ in
                self?.listener?.requestLogout()
            },
            for: .touchUpInside
        )
    }

    var color: UIColor? {
        get {
            view.backgroundColor
        }
        set {
            view.backgroundColor = newValue
        }
    }

}
