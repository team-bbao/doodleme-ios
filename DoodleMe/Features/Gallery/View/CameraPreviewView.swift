//
//  CameraPreviewView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/12/26.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.onScan = onScan
        view.setupSession()
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {}

    class CameraUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((String) -> Void)?
        private var session: AVCaptureSession?

        func setupSession() {
            let session = AVCaptureSession()
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)

            self.session = session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            onScan?(value)
        }
    }
}
