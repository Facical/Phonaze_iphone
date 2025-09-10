// Phonaze_iPhone/Views/WebRemoteView.swift

import SwiftUI
import UIKit

struct WebRemoteView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager

    // 상태 변수
    @State private var urlText: String = ""
    @State private var lastDragPoint: CGPoint? = nil
    
    // 스크롤 감도
    @State private var scrollGain: CGFloat = 1.2

    // 햅틱 피드백
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        VStack(spacing: 12) {
            // 1) 주소창 (기존과 동일)
            HStack(spacing: 8) {
                TextField("URL or Search", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .onSubmit(sendURL)
                Button(action: sendURL) {
                    Image(systemName: "arrow.forward.circle.fill").font(.title2)
                }
                .disabled(urlText.isEmpty)
            }.padding([.horizontal, .top])

            // 2) 트랙패드 영역
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6))
                    VStack {
                        Text("TouchPad").font(.footnote)
                        Text("Tap to Select, Drag to Scroll").font(.caption2) // 텍스트 변경
                    }.foregroundColor(.secondary)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let current = value.location
                            let previous = lastDragPoint ?? value.startLocation
                            
                            let dx = (current.x - previous.x) * scrollGain
                            let dy = (current.y - previous.y) * scrollGain
                            
                            if abs(dx) > 0.1 || abs(dy) > 0.1 {
                                connectivityManager.sendWebScroll(dx: dx, dy: dy)
                                impactLight.impactOccurred(intensity: 0.5)
                            }
                            lastDragPoint = current
                        }
                        .onEnded { value in
                            let distance = hypot(value.translation.width, value.translation.height)
                            if distance < 10 {
                                // ✅ [핵심 수정] 탭 위치와 관계없이 항상 화면 중앙(0.5, 0.5)을 클릭하도록 신호를 보냅니다.
                                // 이것이 Vision Pro에서 "바라보는 곳을 탭"하는 경험을 구현합니다.
                                connectivityManager.sendWebTap(nx: 0.5, ny: 0.5)
                                impactMedium.impactOccurred()
                            }
                            lastDragPoint = nil
                        }
                )
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)
            
            // 3) 네비게이션 버튼 (기존과 동일)
            HStack(spacing: 20) {
                Button(action: { sendNav("BACK") }) { NavButton(icon: "chevron.left") }
                Button(action: { sendNav("FORWARD") }) { NavButton(icon: "chevron.right") }
                Button(action: { sendNav("RELOAD") }) { NavButton(icon: "arrow.clockwise") }
            }.padding(.bottom)
        }
        .navigationTitle("Web Remote")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendURL() {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let msg = "WEB_URL:" + (text.contains("://") || text.contains(".") ? text : "https://www.google.com/search?q=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        connectivityManager.sendMessage(msg)
        notificationFeedback.notificationOccurred(.success)
    }

    private func sendNav(_ cmd: String) {
        connectivityManager.sendMessage("WEB_NAV:\(cmd)")
        notificationFeedback.notificationOccurred(.success)
    }

    struct NavButton: View {
        let icon: String
        var body: some View {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .frame(width: 60, height: 60)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
    }
}
