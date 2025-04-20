import Foundation

struct HistoryEvent: Identifiable, Decodable {
    let id: Int
    let vehicleId: String
    let action: String
    let timestamp: Date

    private enum CodingKeys: String, CodingKey {
        case id, vehicleId, action, timestamp
    }
}
