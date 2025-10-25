import Foundation

struct LocalizedText: Codable, Hashable {
    let ar: String
    let he: String

    init(ar: String = "", he: String = "") {
        self.ar = ar
        self.he = he
    }

    var preferred: String {
        let trimmedArabic = ar.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedArabic.isEmpty { return trimmedArabic }

        let trimmedHebrew = he.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHebrew.isEmpty { return trimmedHebrew }

        return ""
    }
}

struct Product: Identifiable, Codable, Hashable {
    enum OwnershipType: String, Codable {
        case ours
        case local
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = (try? container.decode(String.self)) ?? ""
            self = OwnershipType(rawValue: rawValue) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .ours:
                try container.encode("ours")
            case .local:
                try container.encode("local")
            case .unknown:
                try container.encodeNil()
            }
        }
    }

    enum Priority: String, Codable {
        case a = "A"
        case b = "B"
        case c = "C"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = (try? container.decode(String.self)) ?? ""
            self = Priority(rawValue: raw.uppercased()) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .a:
                try container.encode("A")
            case .b:
                try container.encode("B")
            case .c:
                try container.encode("C")
            case .unknown:
                try container.encodeNil()
            }
        }
    }

    let id: String
    let name: LocalizedText
    let description: LocalizedText
    let category: String?
    let mainCategory: String
    let subCategory: String
    let images: [String]
    let ownershipType: OwnershipType
    let priority: Priority
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case description
        case category
        case mainCategory
        case subCategory
        case images
        case ownershipType
        case priority
        case createdAt
        case updatedAt
    }

    var primaryImageURL: URL? {
        guard let first = images.first else { return nil }
        return URL(string: first)
    }

    var displayName: String { name.preferred }

    var secondaryText: String {
        let trimmedDescription = description.preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty {
            return trimmedDescription
        }
        if let category, !category.isEmpty {
            return category
        }
        return subCategory
    }
}
