//import Combine
//import Foundation
//
//extension Publisher {
//    func withLatestFrom<Other: Publisher>(
//        _ other: Other
//    ) -> AnyPublisher<Other.Output, Other.Failure>
//    where Failure == Other.Failure {
//        let upstream = share()
//
//        return other
//            .map { second in upstream.map { _ in second  } }
//            .switchToLatest()
//            .zip(upstream) // `zip`ping and discarding `\.1` allows for
//        // upstream completions to be projected down immediately.
//            .map(\.0)
//            .eraseToAnyPublisher()
//    }
//}
