import Foundation
import CoreLocation

struct Vehicle: Identifiable, Decodable {
    enum RideState: String, Decodable, CaseIterable {
        case waiting    = "waiting"
        case inProgress = "in_progress"
        case stopped    = "stopped"
    }

    let id: String
    let name: String
    var coordinate: CLLocationCoordinate2D
    var rideState: RideState

    /// Explicit initializer (used by MockDataProvider)
    init(id: String,
         name: String,
         coordinate: CLLocationCoordinate2D,
         rideState: RideState) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.rideState = rideState
    }

    // MARK: – Decodable

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, rideState = "state"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        name      = try c.decode(String.self, forKey: .name)
        rideState = try c.decode(RideState.self, forKey: .rideState)
        let lat   = try c.decode(CLLocationDegrees.self, forKey: .latitude)
        let lon   = try c.decode(CLLocationDegrees.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
