import SwiftUI

struct VehicleDetailView: View {
    @EnvironmentObject var viewModel: MapViewModel
    let vehicle: Vehicle

    @Environment(\.presentationMode) private var presentationMode
    @State private var isScanning = false

    private var title: String {
        switch vehicle.rideState {
        case .waiting:    return "Start Ride"
        case .inProgress: return "Stop Ride"
        case .stopped:    return "Waiting"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.top, 8)

            Text("Vehicle: \(vehicle.name)")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("ID: \(vehicle.id)")
                Text("State: \(vehicle.rideState.rawValue.capitalized)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 12) {
                if vehicle.rideState == .waiting {
                    Button(title) { viewModel.startRide() }
                        .buttonStyle(ActionButtonStyle())
                    Button("Scan QR to Start") { isScanning = true }
                        .buttonStyle(ActionButtonStyle())
                } else if vehicle.rideState == .inProgress {
                    Button(title) { viewModel.stopRide() }
                        .buttonStyle(ActionButtonStyle())
                } else {
                    Text("No actions available")
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $isScanning) {
            QRScannerView { code in
                isScanning = false
                if let v = viewModel.vehicles.first(where: { $0.id == code }) {
                    viewModel.selectVehicle(v)
                    viewModel.startRide()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

/// A simple filled button style for callout actions
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.6 : 1))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
