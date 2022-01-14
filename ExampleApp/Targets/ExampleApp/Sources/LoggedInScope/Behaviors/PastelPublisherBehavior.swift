import Combine
import Foundation
import ScopeKit
import UIKit

final class PastePublisherBehavior: Behavior {

    private let pastelSubject = CurrentValueSubject<UIColor, Never>(.gray)

    var pastelPublisher: AnyPublisher<UIColor, Never> {
        pastelSubject.eraseToAnyPublisher()
    }

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                pastelSubject.send(.randomPastel)
            }
            .store(in: &cancellables)
    }

}

extension UIColor {

    private static var randomLightness: CGFloat {
        Double.random(in: 0...1)
    }

    private static var randomRGB: UIColor {
        UIColor(
            red: randomLightness,
            green: randomLightness,
            blue: randomLightness,
            alpha: 1
        )
    }

    static var randomPastel: UIColor {
        let rgb = randomRGB

        // Extract the sample's HSB/HSV values.
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let pastelHue = hue
        let pastelSaturation = 0.05 + (saturation * 0.35)
        let pastelBrightness = 0.6 + (brightness * 0.4)

        return UIColor(
            hue: pastelHue,
            saturation: pastelSaturation,
            brightness: pastelBrightness,
            alpha: 1
        )
    }


}
