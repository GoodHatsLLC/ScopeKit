import Combine
import Foundation

protocol ReceiverListener: AnyObject {
    func receiveProxied(cancellables: Set<AnyCancellable>)
}

public class CancellableReceiver {

    private weak var listener: ReceiverListener?

    init(listener: ReceiverListener) {
        self.listener = listener
    }

    public var cancellables: Set<AnyCancellable> {
        get {
            Set<AnyCancellable>()
        }
        set {
            listener?.receiveProxied(cancellables: newValue)
        }
    }
}
