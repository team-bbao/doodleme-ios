//
//  QRScannerView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/12/26.
//

import SwiftData
import SwiftUI

struct QRScannerView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var scanned: PostTransferData?
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewView { result in
                    guard scanned == nil else { return }
                    // QR 안에는 딥링크 URL 이 들어 있다. 딥링크 수신과 같은 경로로 해석한다.
                    scanned = URL(string: result).flatMap(PostTransferData.decode(deepLink:))
                        ?? PostTransferData.decode(from: result)
                }
                .ignoresSafeArea()

                // 스캔 가이드 프레임
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.8), lineWidth: 3)
                    .frame(width: 260, height: 260)

                VStack {
                    Spacer()

                    if let data = scanned {
                        scannedPreview(data: data)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 50)
                    } else {
                        Text("QR 코드를 네모 안에 비춰주세요")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.bottom, 50)
                    }
                }
            }
            .navigationTitle("QR 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .alert("저장 완료", isPresented: $showAlert) {
                Button("확인") { scanned = nil }
            } message: {
                Text(alertMessage)
            }
        }
    }

    @ViewBuilder
    private func scannedPreview(data: PostTransferData) -> some View {
        VStack(spacing: 14) {
            Text("QR 인식됨")
                .font(.headline)
                .foregroundStyle(.white)

            if let name = data.n, !name.isEmpty {
                Text("From. \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(data.t.isEmpty ? "(텍스트 없음)" : "\"\(data.t)\"")
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 12) {
                Button("다시 스캔") {
                    scanned = nil
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())

                Button("저장하기") {
                    importPost(data: data)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white)
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func importPost(data: PostTransferData) {
        modelContext.insert(data.makePost())
        alertMessage = "By others에 그림이 저장됐어요."
        showAlert = true
    }
}

#Preview {
    QRScannerView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
