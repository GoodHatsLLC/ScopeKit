import Combine
@testable import ScopeKit

enum ReportingTestEvent {
    case state
}

final class ReportingScope: Scope {

    private let startCallback: (() -> ())?
    private let stopCallback: (() -> ())?
    private let endCallback: (() -> ())?
    private let eventPublisher: AnyPublisher<ReportingTestEvent, Error>
    var willStartCount = 0
    var willStopCount = 0
    var willEndCount = 0

    required init(
        eventPublisher: AnyPublisher<ReportingTestEvent, Error> = Empty<ReportingTestEvent, Error>().eraseToAnyPublisher(),
        start: (() -> ())? = nil,
        stop:  (() -> ())? = nil,
        end:  (() -> ())? = nil
    ) {
        self.startCallback = start
        self.stopCallback = stop
        self.endCallback = end
        self.eventPublisher = eventPublisher
    }

    override func willStart() -> CancelBag {
        startCallback?()
        willStartCount += 1
        return CancelBag {
            eventPublisher
                .sink(receiveCompletion: {_ in }, receiveValue: {_ in })
        }
    }

    override func willStop() {
        stopCallback?()
        willStopCount += 1
    }

    override func willEnd() {
        endCallback?()
        willEndCount += 1
    }
}

