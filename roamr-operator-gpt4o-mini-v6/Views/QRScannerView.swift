import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    /// Called with the decoded vehicle ID
    var onCodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        let session = AVCaptureSession()

        // 1️⃣ Set up camera input
        if let device = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device) {
            session.addInput(input)
        }

        // 2️⃣ Set up metadata output
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        // 3️⃣ Add preview layer on main thread
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            previewLayer.frame = vc.view.bounds
            vc.view.layer.addSublayer(previewLayer)
        }

        // 4️⃣ Start session off the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // no-op
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: QRScannerView

        init(parent: QRScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  obj.type == .qr,
                  let raw = obj.stringValue else { return }

            // Expect URLs like myapp://startRide?vehicleId=2
            if let url = URL(string: raw),
               url.scheme == "myapp",
               let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
               let id = items.first(where: { $0.name == "vehicleId" })?.value {
                DispatchQueue.main.async {
                    print("🔑 Scanned ID:", id)
                    self.parent.onCodeScanned(id)
                }
            }
        }
    }
}
