// Phonaze_iPhone/SelectView.swift

import SwiftUI

struct SelectView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 화면 전체를 연한 노란색으로 채워 탭 영역임을 표시
                Color.yellow.opacity(0.3)

                Text("Tap anywhere to select the panel\nyou are looking at in Vision Pro.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .contentShape(Rectangle()) // ZStack 전체가 탭 제스처를 받도록 함
            .onTapGesture {
                // 탭 위치와 관계없이 "TAP" 메시지를 전송
                let message = "TAP:\(UUID().uuidString)"
                connectivityManager.sendMessage(message)
                print("Sent message: \(message)")
            }
        }
        .navigationTitle("Select Controller")
        .ignoresSafeArea() // 화면 전체를 사용
    }
}

struct SelectView_Previews: PreviewProvider {
    static var previews: some View {
        SelectView()
            .environmentObject(ConnectivityManager())
    }
}
