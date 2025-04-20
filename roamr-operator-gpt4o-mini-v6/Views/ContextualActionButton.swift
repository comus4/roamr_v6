import SwiftUI

struct ContextualActionButton: View {
    @EnvironmentObject var viewModel: MapViewModel
    let vehicle: Vehicle

    private var title: String {
        switch vehicle.rideState {
        case .waiting:    return "Start"
        case .inProgress: return "Stop"
        case .stopped:    return "Waiting"
        }
    }

    var body: some View {
        Button(action: perform) {
            if viewModel.isBusy {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .disabled(viewModel.isBusy)
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
    }

    private func perform() {
        switch vehicle.rideState {
        case .waiting:
            viewModel.startRide()
        case .inProgress:
            viewModel.stopRide()
        case .stopped:
            break
        }
    }
}
