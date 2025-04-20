import SwiftUI

struct VehicleAnnotationView: View {
    let vehicle: Vehicle
    let isSelected: Bool

    @State private var pulse = false

    var body: some View {
        Image(systemName: "car.fill")
            .font(.title)
            .scaleEffect(isSelected ? 1.3 : 1)
            .scaleEffect(pulse ? 1.5 : 1)
            .foregroundColor(color)
            .shadow(radius: isSelected ? 5 : 0)
            // new two‑parameter onChange in iOS 17
            .onChange(of: vehicle.rideState) { _, _ in
                pulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pulse = false }
            }
            .animation(.easeInOut, value: pulse)
    }

    private var color: Color {
        switch vehicle.rideState {
        case .waiting:    return .blue
        case .inProgress: return .green
        case .stopped:    return .gray
        }
    }
}
