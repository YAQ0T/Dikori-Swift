import Foundation

struct Order: Identifiable, Codable, Hashable {
    struct UserSummary: Codable, Hashable {
        let id: String?
        let name: String
        let phone: String
        let email: String

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case phone
            case email
        }

        init(id: String? = nil, name: String = "", phone: String = "", email: String = "") {
            self.id = id
            self.name = name
            self.phone = phone
            self.email = email
        }
    }

    struct GuestInfo: Codable, Hashable {
        let name: String
        let phone: String
        let email: String
        let address: String

        init(name: String = "", phone: String = "", email: String = "", address: String = "") {
            self.name = name
            self.phone = phone
            self.email = email
            self.address = address
        }
    }

    struct Item: Identifiable, Codable, Hashable {
        let id: String
        let productId: String
        let variantId: String
        let name: LocalizedText
        let quantity: Int
        let price: Double
        let color: String?
        let measure: String?
        let sku: String?
        let image: String?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case productId
            case variantId
            case name
            case quantity
            case price
            case color
            case measure
            case sku
            case image
        }

        init(
            id: String = UUID().uuidString,
            productId: String,
            variantId: String,
            name: LocalizedText = LocalizedText(),
            quantity: Int = 1,
            price: Double = 0,
            color: String? = nil,
            measure: String? = nil,
            sku: String? = nil,
            image: String? = nil
        ) {
            self.id = id
            self.productId = productId
            self.variantId = variantId
            self.name = name
            self.quantity = quantity
            self.price = price
            self.color = color
            self.measure = measure
            self.sku = sku
            self.image = image
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let explicitID = try container.decodeIfPresent(String.self, forKey: .id)
            let productId = try container.decode(String.self, forKey: .productId)
            let variantId = try container.decode(String.self, forKey: .variantId)
            let name = try container.decodeIfPresent(LocalizedText.self, forKey: .name) ?? LocalizedText()
            let quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
            let price = try container.decodeIfPresent(Double.self, forKey: .price) ?? 0
            let color = try container.decodeIfPresent(String.self, forKey: .color)
            let measure = try container.decodeIfPresent(String.self, forKey: .measure)
            let sku = try container.decodeIfPresent(String.self, forKey: .sku)
            let image = try container.decodeIfPresent(String.self, forKey: .image)

            self.init(
                id: explicitID ?? UUID().uuidString,
                productId: productId,
                variantId: variantId,
                name: name,
                quantity: quantity,
                price: price,
                color: color,
                measure: measure,
                sku: sku,
                image: image
            )
        }

        var displayName: String { name.preferred }
        var totalPrice: Double { Double(quantity) * price }
    }

    struct Discount: Codable, Hashable {
        enum DiscountType: String, Codable {
            case percent
            case fixed
            case none

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = (try? container.decode(String.self)) ?? ""
                self = DiscountType(rawValue: rawValue) ?? .none
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .percent:
                    try container.encode("percent")
                case .fixed:
                    try container.encode("fixed")
                case .none:
                    try container.encodeNil()
                }
            }
        }

        let applied: Bool
        let ruleId: String?
        let type: DiscountType
        let value: Double
        let amount: Double
        let threshold: Double
        let name: String

        init(
            applied: Bool = false,
            ruleId: String? = nil,
            type: DiscountType = .none,
            value: Double = 0,
            amount: Double = 0,
            threshold: Double = 0,
            name: String = ""
        ) {
            self.applied = applied
            self.ruleId = ruleId
            self.type = type
            self.value = value
            self.amount = amount
            self.threshold = threshold
            self.name = name
        }
    }

    enum Status: String, Codable, Hashable, CaseIterable {
        case pending
        case waitingConfirmation = "waiting_confirmation"
        case onTheWay = "on_the_way"
        case delivered
        case cancelled
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = (try? container.decode(String.self)) ?? ""
            self = Status(rawValue: raw) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .pending:
                try container.encode("pending")
            case .waitingConfirmation:
                try container.encode("waiting_confirmation")
            case .onTheWay:
                try container.encode("on_the_way")
            case .delivered:
                try container.encode("delivered")
            case .cancelled:
                try container.encode("cancelled")
            case .unknown:
                try container.encodeNil()
            }
        }

        var localizedTitle: String {
            switch self {
            case .pending:
                return "بانتظار المعالجة"
            case .waitingConfirmation:
                return "بانتظار التأكيد"
            case .onTheWay:
                return "في الطريق"
            case .delivered:
                return "تم التوصيل"
            case .cancelled:
                return "ملغي"
            case .unknown:
                return "غير معروف"
            }
        }
    }

    enum PaymentMethod: String, Codable, Hashable {
        case card
        case cashOnDelivery = "cod"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = (try? container.decode(String.self)) ?? ""
            self = PaymentMethod(rawValue: raw) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .card:
                try container.encode("card")
            case .cashOnDelivery:
                try container.encode("cod")
            case .unknown:
                try container.encodeNil()
            }
        }

        var localizedTitle: String {
            switch self {
            case .card:
                return "بطاقة"
            case .cashOnDelivery:
                return "الدفع عند الاستلام"
            case .unknown:
                return "غير محدد"
            }
        }
    }

    enum PaymentStatus: String, Codable, Hashable {
        case unpaid
        case paid
        case failed
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = (try? container.decode(String.self)) ?? ""
            self = PaymentStatus(rawValue: raw) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .unpaid:
                try container.encode("unpaid")
            case .paid:
                try container.encode("paid")
            case .failed:
                try container.encode("failed")
            case .unknown:
                try container.encodeNil()
            }
        }

        var localizedTitle: String {
            switch self {
            case .unpaid:
                return "غير مدفوع"
            case .paid:
                return "مدفوع"
            case .failed:
                return "فشل الدفع"
            case .unknown:
                return "غير معروف"
            }
        }
    }

    struct PaymentDetails: Codable, Hashable {
        let method: PaymentMethod
        let currency: String
        let status: PaymentStatus
        let reference: String?
        let verifiedAmount: Double?
        let verifiedCurrency: String
        let transactionId: String
        let cardType: String
        let cardLast4: String

        init(
            method: PaymentMethod = .unknown,
            currency: String = "ILS",
            status: PaymentStatus = .unknown,
            reference: String? = nil,
            verifiedAmount: Double? = nil,
            verifiedCurrency: String = "",
            transactionId: String = "",
            cardType: String = "",
            cardLast4: String = ""
        ) {
            self.method = method
            self.currency = currency
            self.status = status
            self.reference = reference
            self.verifiedAmount = verifiedAmount
            self.verifiedCurrency = verifiedCurrency
            self.transactionId = transactionId
            self.cardType = cardType
            self.cardLast4 = cardLast4
        }

        private enum CodingKeys: String, CodingKey {
            case method = "paymentMethod"
            case currency = "paymentCurrency"
            case status = "paymentStatus"
            case reference
            case verifiedAmount = "paymentVerifiedAmount"
            case verifiedCurrency = "paymentVerifiedCurrency"
            case transactionId = "paymentTransactionId"
            case cardType = "paymentCardType"
            case cardLast4 = "paymentCardLast4"
        }
    }

    let id: String
    let user: UserSummary?
    let guestInfo: GuestInfo
    let isGuest: Bool
    let items: [Item]
    let subtotal: Double
    let discount: Discount?
    let total: Double
    let address: String
    let status: Status
    let deliveredAt: Date?
    let payment: PaymentDetails
    let notes: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user
        case guestInfo
        case isGuest
        case items
        case subtotal
        case discount
        case total
        case address
        case status
        case deliveredAt
        case paymentMethod
        case paymentCurrency
        case paymentStatus
        case reference
        case paymentVerifiedAmount
        case paymentVerifiedCurrency
        case paymentTransactionId
        case paymentCardType
        case paymentCardLast4
        case notes
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        user: UserSummary? = nil,
        guestInfo: GuestInfo = GuestInfo(),
        isGuest: Bool = false,
        items: [Item] = [],
        subtotal: Double = 0,
        discount: Discount? = nil,
        total: Double = 0,
        address: String = "",
        status: Status = .unknown,
        deliveredAt: Date? = nil,
        payment: PaymentDetails = PaymentDetails(),
        notes: String = "",
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.user = user
        self.guestInfo = guestInfo
        self.isGuest = isGuest
        self.items = items
        self.subtotal = subtotal
        self.discount = discount
        self.total = total
        self.address = address
        self.status = status
        self.deliveredAt = deliveredAt
        self.payment = payment
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(String.self, forKey: .id)
        let user = try container.decodeIfPresent(UserSummary.self, forKey: .user)
        let guestInfo = try container.decodeIfPresent(GuestInfo.self, forKey: .guestInfo) ?? GuestInfo()
        let isGuest = try container.decodeIfPresent(Bool.self, forKey: .isGuest) ?? false
        let items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        let subtotal = try container.decodeIfPresent(Double.self, forKey: .subtotal) ?? 0
        let discount = try container.decodeIfPresent(Discount.self, forKey: .discount)
        let total = try container.decodeIfPresent(Double.self, forKey: .total) ?? 0
        let address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        let status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .unknown
        let deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)

        let method = try container.decodeIfPresent(PaymentMethod.self, forKey: .paymentMethod) ?? .unknown
        let currency = try container.decodeIfPresent(String.self, forKey: .paymentCurrency) ?? ""
        let statusPayment = try container.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus) ?? .unknown
        let reference = try container.decodeIfPresent(String.self, forKey: .reference)
        let verifiedAmount = try container.decodeIfPresent(Double.self, forKey: .paymentVerifiedAmount)
        let verifiedCurrency = try container.decodeIfPresent(String.self, forKey: .paymentVerifiedCurrency) ?? ""
        let transactionId = try container.decodeIfPresent(String.self, forKey: .paymentTransactionId) ?? ""
        let cardType = try container.decodeIfPresent(String.self, forKey: .paymentCardType) ?? ""
        let cardLast4 = try container.decodeIfPresent(String.self, forKey: .paymentCardLast4) ?? ""

        let payment = PaymentDetails(
            method: method,
            currency: currency,
            status: statusPayment,
            reference: reference,
            verifiedAmount: verifiedAmount,
            verifiedCurrency: verifiedCurrency,
            transactionId: transactionId,
            cardType: cardType,
            cardLast4: cardLast4
        )

        let notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        self.init(
            id: id,
            user: user,
            guestInfo: guestInfo,
            isGuest: isGuest,
            items: items,
            subtotal: subtotal,
            discount: discount,
            total: total,
            address: address,
            status: status,
            deliveredAt: deliveredAt,
            payment: payment,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = payment.currency.isEmpty ? "ILS" : payment.currency
        return formatter
    }

    func formattedTotal() -> String {
        let formatter = currencyFormatter
        let number = NSNumber(value: total)
        return formatter.string(from: number) ?? String(format: "%.2f", total)
    }
}

extension Order {
    static func samples() -> [Order] {
        let item1 = Item(
            productId: "product-1",
            variantId: "variant-1",
            name: LocalizedText(ar: "مزهرية خزف", he: "אגרטל קרמי"),
            quantity: 1,
            price: 120,
            color: "أبيض",
            sku: "SKU-001",
            image: "https://example.com/vase.jpg"
        )

        let item2 = Item(
            productId: "product-2",
            variantId: "variant-2",
            name: LocalizedText(ar: "وسادة مخمل", he: "כרית קטיפה"),
            quantity: 2,
            price: 85,
            color: "أزرق",
            sku: "SKU-002",
            image: "https://example.com/pillow.jpg"
        )

        let payment = PaymentDetails(
            method: .card,
            currency: "ILS",
            status: .paid,
            reference: "ORD-2024-0001",
            verifiedAmount: 290,
            verifiedCurrency: "ILS",
            transactionId: "TX123456789",
            cardType: "Visa",
            cardLast4: "1234"
        )

        let order = Order(
            id: "order-1",
            user: UserSummary(id: "user-1", name: "ليلى أحمد", phone: "+972500000000", email: "leila@example.com"),
            guestInfo: GuestInfo(),
            isGuest: false,
            items: [item1, item2],
            subtotal: 290,
            discount: Discount(applied: false),
            total: 290,
            address: "القدس، شارع النخيل 12",
            status: .delivered,
            deliveredAt: Date().addingTimeInterval(-86_400),
            payment: payment,
            notes: "تم التسليم في الفترة الصباحية",
            createdAt: Date().addingTimeInterval(-172_800),
            updatedAt: Date().addingTimeInterval(-86_400)
        )

        return [order]
    }
}
