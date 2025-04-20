import Foundation
import Combine
import CoreLocation

/// Mock backend that seeds **20 vehicles**:
/// • 10 **dynamic** (move & randomly flip state every 10 s)
/// • 10 **static** (never move unless user starts/stops them)
final class MockDataProvider: APIServiceProtocol {
    // Poll every 10 s
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private var center: CLLocationCoordinate2D
    private var vehicles: [Vehicle]             // 20 total
    private var staticIds: Set<String>          // 10 ids remain unmoving
    private var lapRoutes: [String: [CLLocationCoordinate2D]] = [:]

    // Pre‑computed circular route for moving vehicles
    private let lapRoute: [CLLocationCoordinate2D]

    // MARK: – Init

    init(center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749,
                                                                 longitude: -122.4194)) {
        self.center = center

        // 1. Create 20 vehicles around the center
        self.vehicles = MockDataProvider.seedVehicles(around: center, count: 20)

        // 2. Pick 10 random ids to stay static
        let ids = vehicles.map { $0.id }
        self.staticIds = Set(ids.shuffled().prefix(10))

        // 3. Build a simple circular “lap” path (36 points)
        var path: [CLLocationCoordinate2D] = []
        let radius = 0.002
        for i in 0..<36 {
            let θ = (Double(i) / 36) * 2 * .pi
            path.append(CLLocationCoordinate2D(latitude: center.latitude  + radius * cos(θ),
                                               longitude: center.longitude + radius * sin(θ)))
        }
        self.lapRoute = path
    }

    // MARK: – APIServiceProtocol

    func fetchVehicles() -> AnyPublisher<[Vehicle], Error> {
        timer
            .map { [weak self] _ in
                guard let self else { return [] }
                self.mutateVehicles()
                return self.vehicles
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    func startRide(vehicleID: String) -> AnyPublisher<Void, Error> {
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].rideState = .inProgress
            lapRoutes[vehicleID] = lapRoute         // assign lap irrespective of static/dynamic
        }
        return Just(())
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func stopRide(vehicleID: String) -> AnyPublisher<Void, Error> {
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].rideState = .stopped
        }
        lapRoutes.removeValue(forKey: vehicleID)
        return Just(())
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    // Optional protocol stubs
    func logEvent(vehicleID: String, action: String) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func fetchHistory() -> AnyPublisher<[HistoryEvent], Error> {
        Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    // MARK: – Public helper for GPS recenter

    func updateCenter(to newCenter: CLLocationCoordinate2D) {
        center = newCenter
        vehicles = MockDataProvider.seedVehicles(around: center, count: 20)
    }

    // MARK: – Internal mutation on each tick

    private func mutateVehicles() {
        for idx in vehicles.indices {
            var v = vehicles[idx]

            // STATIC — leave unless user put it in .inProgress (then follow lap)
            if staticIds.contains(v.id), v.rideState != .inProgress {
                vehicles[idx] = v
                continue
            }

            // If inProgress → follow lapRoute step
            if v.rideState == .inProgress,
               var route = lapRoutes[v.id],
               !route.isEmpty {
                v.coordinate = route.removeFirst()
                lapRoutes[v.id] = route
                if route.isEmpty {
                    v.rideState = .stopped          // auto‑stop when lap done
                    lapRoutes.removeValue(forKey: v.id)
                }
            } else {
                // DYNAMIC idle vehicles: small jitter
                v.coordinate.latitude  += Double.random(in: -0.001...0.001)
                v.coordinate.longitude += Double.random(in: -0.001...0.001)
                // 15 % chance to auto‑start itself
                if v.rideState == .waiting, Double.random(in: 0..<1) < 0.15 {
                    v.rideState = .inProgress
                    lapRoutes[v.id] = lapRoute
                }
            }
            vehicles[idx] = v
        }
    }

    // MARK: – Seeder

    private static func seedVehicles(around center: CLLocationCoordinate2D,
                                     count: Int) -> [Vehicle] {
        (1...count).map { i in
            let jitter = 0.007
            let lat = center.latitude  + Double.random(in: -jitter...jitter)
            let lon = center.longitude + Double.random(in: -jitter...jitter)
            let state = Vehicle.RideState.allCases.randomElement()!
            return Vehicle(
                id: "\(i)",
                name: "Veh\(i)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                rideState: state
            )
        }
    }
}
