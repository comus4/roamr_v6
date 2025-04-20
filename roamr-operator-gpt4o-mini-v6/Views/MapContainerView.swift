import SwiftUI
import MapKit

struct MapContainerView: View {
    @EnvironmentObject var viewModel: MapViewModel
    @StateObject private var locManager = LocationManager.shared

    // Camera
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    // Flow flags
    @State private var isScanning      = false
    @State private var hasCenteredOnce = false
    @State private var userPanned      = false      // ← prevents auto‑recentre

    // Toast
    @State private var showToast = false
    @State private var toastMsg  = ""

    var body: some View {
        ZStack(alignment: .bottom) {

            // ───────────── Map + initial spinner ─────────────
            ZStack {
                if viewModel.vehicles.isEmpty {
                    ProgressView("Loading vehicles…")
                        .progressViewStyle(.circular)
                }

                Map(coordinateRegion: $region,
                    annotationItems: viewModel.vehicles) { vehicle in
                    MapAnnotation(coordinate: vehicle.coordinate) {
                        VehicleAnnotationView(
                            vehicle: vehicle,
                            isSelected: vehicle.id == viewModel.selectedVehicle?.id
                        )
                        .onTapGesture { viewModel.selectVehicle(vehicle) }
                    }
                }
                // iOS 17: any camera change counts as user pan
                .onMapCameraChange {
                    userPanned = true
                }
                // iOS 16 fallback: transparent drag gesture
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in userPanned = true }
                )
            }
            // Auto‑fit only once
            .onReceive(viewModel.$vehicles) { pins in
                guard !hasCenteredOnce else { return }
                fitRegion(to: pins)
            }
            // GPS update — honour userPanned flag
            .onReceive(locManager.$lastLocation.compactMap { $0 }) { loc in
                guard !userPanned else { return }
                viewModel.updateMockCenter(to: loc)
                withAnimation(.easeInOut) { region.center = loc }
                hasCenteredOnce = true
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                locManager.requestLocation()
                viewModel.startPolling()
            }

            // ───────────── Re‑centre button ─────────────
            Button {
                if let gps = locManager.lastLocation {
                    withAnimation(.easeInOut) { region.center = gps }
                    userPanned      = false   // enable auto‑track again
                    hasCenteredOnce = true
                }
            } label: {
                Image(systemName: "location.fill")
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .clipShape(Circle())
            }
            .padding()

            // ───────────── Contextual overlay (QR / Stop) ─────────────
            overlayControls
        }
        // Detail sheet
        .sheet(item: $viewModel.selectedVehicle) { vehicle in
            VehicleDetailView(vehicle: vehicle)
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
        }
        // Toast banner
        .overlay(alignment: .top) {
            if showToast {
                Text(toastMsg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: showToast)
                    .padding(.top, 44)
            }
        }
    }

    // MARK: – Overlay builder

    @ViewBuilder
    private var overlayControls: some View {
        if let v = viewModel.selectedVehicle {
            VStack {
                Spacer()
                if v.rideState == .waiting {
                    qrButton("Start via QR Code") { code in
                        if let match = viewModel.vehicles.first(where: { $0.id == code }) {
                            viewModel.selectVehicle(match)
                            viewModel.startRide()
                            toast("Ride started for \(match.name)")
                        } else { toast("No vehicle found for ID \(code)") }
                    }
                } else if v.rideState == .inProgress {
                    Button {
                        viewModel.stopRide()
                        toast("Ride stopped for \(v.name)")
                    } label: {
                        Text("Stop Ride")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.isBusy)
                }
            }
            .padding(.bottom)
        }
    }

    // MARK: – Helpers

    private func qrButton(_ title: String, handler: @escaping (String)->Void) -> some View {
        Button { isScanning = true } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .disabled(viewModel.isBusy)
        .sheet(isPresented: $isScanning) {
            QRScannerView { code in
                DispatchQueue.main.async {
                    isScanning = false
                    handler(code)
                }
            }
        }
    }

    private func toast(_ msg: String) {
        toastMsg  = msg
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            showToast = false
        }
    }

    private func fitRegion(to pins: [Vehicle]) {
        guard !pins.isEmpty else { return }
        let lats = pins.map { $0.coordinate.latitude }
        let lons = pins.map { $0.coordinate.longitude }
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2,
                                            longitude: (lons.min()! + lons.max()!) / 2)
        let span   = MKCoordinateSpan(latitudeDelta: max((lats.max()! - lats.min()!) * 1.3, 0.005),
                                      longitudeDelta: max((lons.max()! - lons.min()!) * 1.3, 0.005))
        DispatchQueue.main.async {
            withAnimation(.easeInOut) {
                region = MKCoordinateRegion(center: center, span: span)
            }
        }
    }
}
