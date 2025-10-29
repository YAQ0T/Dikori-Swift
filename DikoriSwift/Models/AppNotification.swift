import Foundation

struct AppNotification: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let message: String
    let target: String
    let createdAt: Date
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case message
        case target
        case createdAt
        case isRead
    }
}

extension AppNotification {
    static func samples() -> [AppNotification] {
        let now = Date()
        return [
            AppNotification(
                id: UUID().uuidString,
                title: "ترحيب في ديكوري",
                message: "مرحباً بك! استكشف أحدث المنتجات المضافة هذا الأسبوع.",
                target: "all",
                createdAt: now.addingTimeInterval(-3_600),
                isRead: false
            ),
            AppNotification(
                id: UUID().uuidString,
                title: "خصم خاص",
                message: "منتجاتك المفضلة حصلت على خصم 25٪ لمدة 48 ساعة فقط!",
                target: "all",
                createdAt: now.addingTimeInterval(-86_400),
                isRead: false
            ),
            AppNotification(
                id: UUID().uuidString,
                title: "تذكير",
                message: "لا تنسَ إكمال طلبك. سلة التسوق محفوظة لك.",
                target: "all",
                createdAt: now.addingTimeInterval(-172_800),
                isRead: true
            )
        ]
    }
}
