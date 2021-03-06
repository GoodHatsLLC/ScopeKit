import Foundation

struct AuthenticationToken: Codable, Equatable {

    static var fakeToken: AuthenticationToken {
        AuthenticationToken(
            grantDate: Date(),
            grantDuration: 50
        )
    }

    private static let diskCacheKey = "fake-authentication-token"

    static func fetchFromDiskCache() -> AuthenticationToken? {
        guard let data = UserDefaults.standard.data(forKey: diskCacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthenticationToken.self, from: data)
    }

    func writeToDiskCache() throws {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: Self.diskCacheKey)
        }
    }

    static func eraseDiskCache() {
        UserDefaults.standard.set(nil, forKey: Self.diskCacheKey)
    }

    var isValid: Bool {
        let interval = Date().timeIntervalSince(grantDate)
        return interval < grantDuration
    }

    let grantDate: Date
    let grantDuration: TimeInterval
}
