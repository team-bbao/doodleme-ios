//
//  CameraPreviewView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/12/26.
//

import AVFoundation
import SwiftUI

/// QR 코드를 인식하는 카메라 프리뷰.
struct CameraPreviewView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> CameraSessionController {
        CameraSessionController()
    }

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        context.coordinator.onScan = onScan
        context.coordinator.start(previewLayer: view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        context.coordinator.onScan = onScan
    }

    /// 뷰가 사라질 때 세션을 확실히 멈춘다. 예전에는 이 처리가 없어 카메라가 계속 돌았다.
    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: CameraSessionController) {
        coordinator.stop()
    }
}

/// 프리뷰 레이어를 `layerClass`로 지정하면 뷰의 레이어가 곧 프리뷰 레이어가 된다.
/// sublayer 를 직접 추가하고 `layoutSubviews`에서 크기를 맞춰줄 필요가 없다.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    /// `layerClass` 가 보장하므로 이 변환은 항상 성공한다.
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// `AVCaptureSession` 의 설정과 시작은 비용이 큰 작업이라 메인 스레드에서 하면 화면이 멈칫한다.
/// 세션 관련 상태는 전용 직렬 큐에서만 건드리고, 스캔 결과만 메인 액터로 넘긴다.
final class CameraSessionController: NSObject, AVCaptureMetadataOutputObjectsDelegate {

    var onScan: ((String) -> Void)?

    private nonisolated(unsafe) let session = AVCaptureSession()
    private nonisolated(unsafe) var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "com.ggdr.doodleme.camera-session")

    func start(previewLayer: AVCaptureVideoPreviewLayer) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        sessionQueue.async { [session, sessionQueue] in
            if !self.isConfigured {
                self.configure(session: session, delegateQueue: sessionQueue)
            }
            guard self.isConfigured, !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private nonisolated func configure(session: AVCaptureSession, delegateQueue: DispatchQueue) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: delegateQueue)
        output.metadataObjectTypes = [.qr]

        isConfigured = true
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput objects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let code = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = code.stringValue
        else { return }

        Task { @MainActor in
            self.onScan?(value)
        }
    }
}
