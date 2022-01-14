import Foundation

struct AuthenticationToken: Codable, Equatable {

    static let fakeToken = AuthenticationToken(
        grantDate: Date(),
        grantDuration: 60*5
    )

    static let gracePeriod = 60.0

    private static let diskCacheKey = "authentication-token"

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

    let grantDate: Date
    let grantDuration: TimeInterval
}
