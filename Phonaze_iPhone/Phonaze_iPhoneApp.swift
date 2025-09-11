// Phonaze_iPhone/Phonaze_iPhoneApp.swift

import SwiftUI

@main
struct Phonaze_iPhoneApp: App {
    @StateObject private var connectivityManager = ConnectivityManager()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        // 백그라운드로 갈 때 로그 저장
                        _ = connectivityManager.exportLogs()
                    case .inactive:
                        // 비활성 상태
                        break
                    case .active:
                        // 활성 상태로 돌아올 때
                        if !connectivityManager.isConnected {
                            connectivityManager.startBrowsing()
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }
}
