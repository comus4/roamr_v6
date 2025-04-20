import Foundation
import Combine

/// Defines the operations our app needs for vehicle and history data.
protocol APIServiceProtocol {
    func fetchVehicles() -> AnyPublisher<[Vehicle], Error>
    func startRide(vehicleID: String) -> AnyPublisher<Void, Error>
    func stopRide(vehicleID: String) -> AnyPublisher<Void, Error>
    func logEvent(vehicleID: String, action: String) -> AnyPublisher<Void, Error>
    func fetchHistory() -> AnyPublisher<[HistoryEvent], Error>
}

/// A simple JSON‑Server–compatible implementation of APIServiceProtocol.
final class APIService: APIServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    /// Customize `baseURL` if you host your JSON Server elsewhere.
    init(baseURL: URL = URL(string: "http://192.168.1.100:3000")!,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// GET /vehicles
    func fetchVehicles() -> AnyPublisher<[Vehicle], Error> {
        let url = baseURL.appendingPathComponent("vehicles")
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Vehicle].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    /// PATCH /vehicles/{id} with { "state": "in_progress" }
    func startRide(vehicleID: String) -> AnyPublisher<Void, Error> {
        patchVehicleState(vehicleID: vehicleID, to: "in_progress")
    }

    /// PATCH /vehicles/{id} with { "state": "stopped" }
    func stopRide(vehicleID: String) -> AnyPublisher<Void, Error> {
        patchVehicleState(vehicleID: vehicleID, to: "stopped")
    }

    /// Internal helper for PATCHing the vehicle state.
    private func patchVehicleState(vehicleID: String, to newState: String) -> AnyPublisher<Void, Error> {
        let url = baseURL.appendingPathComponent("vehicles/\(vehicleID)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["state": newState]
        request.httpBody = try? JSONEncoder().encode(body)

        return session.dataTaskPublisher(for: request)
            .map { _ in () }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    /// POST /history { vehicleId, action, timestamp }
    func logEvent(vehicleID: String, action: String) -> AnyPublisher<Void, Error> {
        let url = baseURL.appendingPathComponent("history")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "vehicleId": vehicleID,
            "action": action,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try? JSONEncoder().encode(payload)

        return session.dataTaskPublisher(for: request)
            .map { _ in () }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    /// GET /history
    func fetchHistory() -> AnyPublisher<[HistoryEvent], Error> {
        let url = baseURL.appendingPathComponent("history")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [HistoryEvent].self, decoder: decoder)
            .eraseToAnyPublisher()
    }
}
