import Foundation
import Network

struct IPLocation: Sendable {
    let address: String
    let countryName: String
    let flag: String
}

enum IPLookup {
    private struct Payload: Decodable {
        let ip: String
        let country: String
    }

    private static let endpoint = URL(string: "https://api.country.is/")!

    static func current() async throws -> IPLocation {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10

        // Use the current network settings for each check.
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.data(from: endpoint)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try location(from: data)
    }

    static func location(from data: Data) throws -> IPLocation {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let code = payload.country
        let letters = code.utf8

        guard letters.count == 2,
              letters.allSatisfy({ (65...90).contains($0) }),
              Locale.Region.isoRegions.contains(Locale.Region(code)),
              IPv4Address(payload.ip) != nil || IPv6Address(payload.ip) != nil else {
            throw URLError(.cannotParseResponse)
        }

        let indicators = letters.compactMap { UnicodeScalar(0x1F1E6 + UInt32($0) - 65) }
        let flag = String(String.UnicodeScalarView(indicators))
        let name = Locale(identifier: "ru").localizedString(forRegionCode: code) ?? code

        return IPLocation(address: payload.ip, countryName: name, flag: flag)
    }
}
