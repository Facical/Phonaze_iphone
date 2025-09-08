import SwiftUI
import UIKit   // 햅틱을 위해 필요

struct WebRemoteView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager

    // 주소창 & 입력창 상태
    @State private var urlText: String = ""
    @State private var typeText: String = ""

    // 스크롤 제스처 스로틀링
    @State private var lastDragTime: CFTimeInterval = 0
    @State private var lastDragPoint: CGPoint? = nil
    @State private var dragAccum: CGSize = .zero
    private let throttleInterval: CFTimeInterval = 1.0 / 90.0 // 60Hz

    // 스크롤 감도
    @State private var scrollGain: CGFloat = 1.2

    // 햅틱
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMed   = UIImpactFeedbackGenerator(style: .medium)
    private let notify      = UINotificationFeedbackGenerator()

    var body: some View {
        VStack(spacing: 12) {

            // 1) 주소줄 + 이동
            HStack(spacing: 8) {
                TextField("URL 또는 검색어 입력", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled(true)
                    .onSubmit(sendURL)               // ← onCommit 대신 onSubmit 사용
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                Button(action: sendURL) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.title2)
                }
                .disabled(urlText.isEmpty)
            }
            .padding(.horizontal)

            // 2) 내비게이션 & 유틸
            HStack(spacing: 14) {
                Button { sendNav("BACK");    notify.notificationOccurred(.success) }
                label: { NavIcon("chevron.backward") }

                Button { sendNav("FORWARD"); notify.notificationOccurred(.success) }
                label: { NavIcon("chevron.forward") }

                Button { sendNav("RELOAD");  impactMed.impactOccurred() }
                label: { NavIcon("arrow.clockwise") }

                Spacer()

                // 스크롤 파인 컨트롤
                Button { fineScroll(dx: 0,   dy: -120) }
                label: { NavText("↑") }

                Button { fineScroll(dx: 0,   dy: 120) }
                label: { NavText("↓") }

                Button { fineScroll(dx: -120, dy: 0) }
                label: { NavText("←") }

                Button { fineScroll(dx: 120, dy: 0) }
                label: { NavText("→") }
            }
            .padding(.horizontal)

            // 3) 트랙패드 영역 (탭/드래그)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator), lineWidth: 1)
                        )

                    VStack(spacing: 6) {
                        Text("TouchPad").font(.footnote).foregroundColor(.secondary)
                        Text("탭: 클릭  |  드래그: 스크롤")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            sendScrollIfNeeded(current: value.location,
                                               previous: value.startLocation,
                                               in: geo.size)
                        }
                        .onEnded { value in
                            let move = hypot(value.translation.width, value.translation.height)
                            if move < 6 {
                                // 탭: 0~1 정규화 좌표로 전송
                                let nx = max(0, min(1, value.location.x / geo.size.width ))
                                let ny = max(0, min(1, value.location.y / geo.size.height))
                                connectivityManager.sendMessage("WEB_TAP:\(nx),\(ny)")
                                impactLight.impactOccurred()
                            } else {
                                flushScroll()
                            }
                            lastDragPoint = nil
                            dragAccum = .zero
                        }
                )
            }
            .frame(height: 320)
            .padding(.horizontal)

            // 4) 텍스트 전송
            HStack(spacing: 8) {
                TextField("Vision의 입력칸으로 보낼 텍스트", text: $typeText)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                Button {
                    guard !typeText.isEmpty else { return }
                    connectivityManager.sendMessage("WEB_TYPE:\(typeText)")
                    impactLight.impactOccurred()
                    typeText = ""
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                }

                Button {
                    connectivityManager.sendMessage("WEB_KEY:ENTER")
                    impactMed.impactOccurred()
                } label: {
                    Text("Enter").bold()
                }
            }
            .padding(.horizontal)

            // 5) 감도 조절
            HStack {
                Text("스크롤 감도")
                Slider(value: $scrollGain, in: 0.5...2.0, step: 0.1)
                Text(String(format: "%.1fx", scrollGain))
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .navigationTitle("Web Remote")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func sendURL() {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let msg: String
        if text.contains("://") {
            msg = "WEB_URL:\(text)"
        } else if text.contains(" ") == false, text.contains(".") {
            msg = "WEB_URL:https://\(text)"
        } else {
            let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            msg = "WEB_URL:https://www.google.com/search?q=\(q)"
        }
        connectivityManager.sendMessage(msg)
        notify.notificationOccurred(.success)
    }

    private func sendNav(_ cmd: String) {
        connectivityManager.sendMessage("WEB_NAV:\(cmd)")
    }

    private func fineScroll(dx: CGFloat, dy: CGFloat) {
        let sx = Int(dx)
        let sy = Int(dy)
        connectivityManager.sendMessage("WEB_SCROLL:\(sx),\(sy)")
        impactLight.impactOccurred()
    }

    /// 스로틀된 연속 스크롤 전송
    private func sendScrollIfNeeded(current: CGPoint, previous: CGPoint, in size: CGSize) {
        let now = CACurrentMediaTime()
        let base = lastDragPoint ?? previous
        var dx = current.x - base.x
        var dy = current.y - base.y

        dx *= scrollGain
        dy *= scrollGain

        dragAccum.width  += dx
        dragAccum.height += dy
        lastDragPoint = current

        if now - lastDragTime >= throttleInterval {
            flushScroll()
            lastDragTime = now
        }
    }

    /// 누적 델타 전송 후 초기화
    private func flushScroll() {
        // 정수 픽셀만 보냄, 소수는 누적에 남겨 더해감
        let sx = Int(dragAccum.width)
        let sy = Int(dragAccum.height)
        if sx != 0 || sy != 0 {
            connectivityManager.sendMessage("WEB_SCROLL:\(sx),\(sy)")
            dragAccum.width  -= CGFloat(sx)
            dragAccum.height -= CGFloat(sy)
        }
    }
}

// 소형 버튼 스타일
@ViewBuilder private func NavIcon(_ sys: String) -> some View {
    Image(systemName: sys)
        .foregroundColor(.primary)
        .frame(width: 36, height: 36)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
}

@ViewBuilder private func NavText(_ text: String) -> some View {
    Text(text)
        .font(.headline)
        .foregroundColor(.primary)
        .frame(width: 36, height: 36)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
}
