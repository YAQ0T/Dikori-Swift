import Foundation

struct LocalizedText: Codable, Hashable {
    let ar: String
    let he: String

    init(ar: String = "", he: String = "") {
        self.ar = ar
        self.he = he
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let ar = try container.decodeIfPresent(String.self, forKey: .ar) ?? ""
            let he = try container.decodeIfPresent(String.self, forKey: .he) ?? ""
            self.init(ar: ar, he: he)
            return
        }

        if let singleValue = try? decoder.singleValueContainer(),
           let stringValue = try? singleValue.decode(String.self) {
            self.init(ar: stringValue, he: "")
            return
        }

        self.init()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ar, forKey: .ar)
        try container.encode(he, forKey: .he)
    }

    private enum CodingKeys: String, CodingKey {
        case ar
        case he
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

    init(
        id: String,
        name: LocalizedText = LocalizedText(),
        description: LocalizedText = LocalizedText(),
        category: String? = nil,
        mainCategory: String = "",
        subCategory: String = "",
        images: [String] = [],
        ownershipType: OwnershipType = .unknown,
        priority: Priority = .unknown,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.mainCategory = mainCategory
        self.subCategory = subCategory
        self.images = images
        self.ownershipType = ownershipType
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(String.self, forKey: .id)
        let name = (try? container.decode(LocalizedText.self, forKey: .name)) ?? LocalizedText()
        let description = (try? container.decode(LocalizedText.self, forKey: .description)) ?? LocalizedText()
        let category = try container.decodeIfPresent(String.self, forKey: .category)
        let mainCategory = try container.decodeIfPresent(String.self, forKey: .mainCategory) ?? ""
        let subCategory = try container.decodeIfPresent(String.self, forKey: .subCategory) ?? ""
        let images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        let ownershipType = (try? container.decode(OwnershipType.self, forKey: .ownershipType)) ?? .unknown
        let priority = (try? container.decode(Priority.self, forKey: .priority)) ?? .unknown
        let createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        let updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        self.init(
            id: id,
            name: name,
            description: description,
            category: category,
            mainCategory: mainCategory,
            subCategory: subCategory,
            images: images,
            ownershipType: ownershipType,
            priority: priority,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(mainCategory, forKey: .mainCategory)
        try container.encode(subCategory, forKey: .subCategory)
        try container.encode(images, forKey: .images)
        try container.encode(ownershipType, forKey: .ownershipType)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}
