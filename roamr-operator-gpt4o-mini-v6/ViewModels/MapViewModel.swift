import Foundation
import Combine
import CoreLocation

final class MapViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var selectedVehicle: Vehicle?
    @Published var isBusy = false                // drives button spinners & disables

    private var cancellables = Set<AnyCancellable>()
    private let apiService: APIServiceProtocol
    private let dataProvider: APIServiceProtocol

    init(apiService: APIServiceProtocol, dataProvider: APIServiceProtocol) {
        self.apiService = apiService
        self.dataProvider = dataProvider
    }

    // MARK: – Polling

    func startPolling() {
        dataProvider.fetchVehicles()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] list in
                    guard let self = self else { return }
                    self.vehicles = list
                    if let sel = self.selectedVehicle,
                       let updated = list.first(where: { $0.id == sel.id }) {
                        self.selectedVehicle = updated
                    }
                  })
            .store(in: &cancellables)
    }

    // MARK: – Selection

    func selectVehicle(_ vehicle: Vehicle) {
        selectedVehicle = vehicle
    }

    // MARK: – Ride actions (optimistic update + rollback)

    func startRide() {
        guard let id = selectedVehicle?.id, !isBusy else { return }
        let snapshot = vehicles
        updateLocal(id, .inProgress)

        isBusy = true
        apiService.startRide(vehicleID: id)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isBusy = false
                if case .failure = result { self?.vehicles = snapshot }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func stopRide() {
        guard let id = selectedVehicle?.id, !isBusy else { return }
        let snapshot = vehicles
        updateLocal(id, .stopped)

        isBusy = true
        apiService.stopRide(vehicleID: id)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isBusy = false
                if case .failure = result { self?.vehicles = snapshot }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    // MARK: – Helper

    private func updateLocal(_ id: String, _ newState: Vehicle.RideState) {
        vehicles = vehicles.map { v in
            var copy = v
            if v.id == id { copy.rideState = newState }
            return copy
        }
        if var sel = selectedVehicle, sel.id == id {
            sel.rideState = newState
            selectedVehicle = sel
        }
    }

    /// Pass GPS updates to mock provider
    func updateMockCenter(to coordinate: CLLocationCoordinate2D) {
        (dataProvider as? MockDataProvider)?.updateCenter(to: coordinate)
    }
}
