import AVFoundation
import SwiftUI
import UIKit

/// A real in-app camera: live AVCaptureSession preview, front-facing by default,
/// with a shutter button. The system photo picker felt like a system photo
/// picker, which is not what taking a vibe check should feel like.
struct CameraView: View {
    var onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permissionDenied {
                deniedState
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay(Color.white.opacity(flash ? 0.85 : 0).ignoresSafeArea())

                VStack {
                    topBar
                    Spacer()
                    shutterRow
                }
                .padding(.vertical, 18)
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.captured) { _, image in
            guard let image else { return }
            onPicked(image)
            dismiss()
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .accessibilityLabel("Close camera")
            Spacer()
            Text("HOLD STILL")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.45)))
            Spacer()
            Button { camera.flip() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .accessibilityLabel("Flip camera")
        }
        .padding(.horizontal, 18)
    }

    private var shutterRow: some View {
        Button {
            withAnimation(.easeOut(duration: 0.06)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.easeIn(duration: 0.16)) { flash = false }
            }
            SFX.shutter()
            camera.capture()
        } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                Circle().fill(.white).frame(width: 64, height: 64)
            }
        }
        .accessibilityLabel("Take photo")
        .accessibilityIdentifier("shutter")
        .padding(.bottom, 22)
    }

    private var deniedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40)).foregroundStyle(.white.opacity(0.7))
            Text("The dog needs to see you")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Camera access is off. Turn it on in Settings and come back.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
            Button("Never mind") { dismiss() }
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
        }
    }
}

/// Hosts the AVCaptureVideoPreviewLayer.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published var captured: UIImage?
    @Published var permissionDenied = false

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    // Read from the capture delegate, which is nonisolated, so it cannot live
    // on the main actor.
    private let mirrorFront = MirrorFlag()
    private var position: AVCaptureDevice.Position = .front {
        didSet { mirrorFront.value = (position == .front) }
    }
    private var configured = false
    // Session work must stay off the main thread or the preview stutters.
    private let queue = DispatchQueue(label: "vibecheck.camera")

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { permissionDenied = true; return }
        default:
            permissionDenied = true
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.configure()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func flip() {
        position = (position == .front) ? .back : .front
        SFX.tap()
        queue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.attachInput()
            self.session.commitConfiguration()
        }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        queue.async { [weak self] in
            guard let self else { return }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Session setup (always on `queue`)

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        attachInput()
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    private func attachInput() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
    }
}

/// Tiny thread-safe box so the nonisolated capture callback can read which
/// camera took the shot without touching main-actor state.
final class MirrorFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = true
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        // The front camera is not mirrored in the file, but the preview is, so
        // flip it back to match what the user just saw.
        let front = mirrorFront.value
        Task { @MainActor [weak self] in
            self?.captured = front ? image.mirroredHorizontally() : image.normalizedUp()
        }
    }
}

extension UIImage {
    /// Bake the EXIF orientation into the pixels so the JPEG we send is upright.
    /// Preserve the original scale - the renderer would otherwise redraw at the
    /// screen scale and silently inflate a camera image.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Mirrors a selfie so the saved photo matches the live preview.
    func mirroredHorizontally() -> UIImage {
        let upright = normalizedUp()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = upright.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: upright.size, format: format).image { ctx in
            ctx.cgContext.translateBy(x: upright.size.width, y: 0)
            ctx.cgContext.scaleBy(x: -1, y: 1)
            upright.draw(in: CGRect(origin: .zero, size: upright.size))
        }
    }
}
