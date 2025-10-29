import Foundation

enum ISO8601Decoder {
    static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let date = fractionalFormatter.date(from: dateString) {
            return date
        }

        if let date = fallbackFormatter.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date string: \(dateString)"
        )
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        return decoder
    }
}
