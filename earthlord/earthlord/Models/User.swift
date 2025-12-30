import Foundation

/// 用户模型
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}
