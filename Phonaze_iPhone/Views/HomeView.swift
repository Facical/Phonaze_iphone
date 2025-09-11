// Phonaze_iPhone/Views/HomeView.swift

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var connectivity: ConnectivityManager
    @State private var showExperimentSettings = false
    @State private var experimentMode: String = "directTouch"
    
    var body: some View {
        VStack(spacing: 20) {
            // 연결 상태 표시
            connectionStatusCard
            
            Text("Choose an action:")
                .font(.headline)
                .padding()
            
            // 실험 모드 토글
            experimentModeToggle
            
            // 기존 네비게이션 링크들
            NavigationLink(destination: SelectView()) {
                ControlButton(
                    title: "Select Panel Control",
                    icon: "hand.tap",
                    color: .blue
                )
            }
            
            NavigationLink(destination: NumberScrollView()) {
                ControlButton(
                    title: "Scroll Control",
                    icon: "scroll",
                    color: .green
                )
            }
            
            // Enhanced Web Remote 추가
            NavigationLink(destination: WebRemoteViewEnhanced()) {
                ControlButton(
                    title: "Enhanced Web Remote",
                    icon: "globe",
                    color: .orange,
                    badge: "NEW"
                )
            }
            
            // 기존 Web Remote (비교용)
            NavigationLink(destination: WebRemoteView()) {
                ControlButton(
                    title: "Basic Web Remote",
                    icon: "hand.draw",
                    color: .gray
                )
            }
            
            Spacer()
            
            // 실험 데이터 내보내기 버튼
            if connectivity.isExperimentMode {
                exportButton
            }
        }
        .navigationTitle("Control Center")
        .sheet(isPresented: $showExperimentSettings) {
            ExperimentSettingsView(
                experimentMode: $experimentMode,
                onConfirm: {
                    connectivity.setExperimentMode(true, mode: experimentMode)
                    showExperimentSettings = false
                }
            )
        }
    }
    
    // MARK: - Subviews
    
    private var connectionStatusCard: some View {
        HStack {
            Circle()
                .fill(connectivity.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            Text(connectivity.isConnected ?
                "Connected to Vision Pro" :
                "Not Connected")
                .font(.subheadline)
            
            Spacer()
            
            if connectivity.isConnected {
                Text(connectivity.connectedPeerName ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var experimentModeToggle: some View {
        HStack {
            Toggle("Experiment Mode", isOn: Binding(
                get: { connectivity.isExperimentMode },
                set: { enabled in
                    if enabled {
                        showExperimentSettings = true
                    } else {
                        connectivity.setExperimentMode(false)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .purple))
            
            if connectivity.isExperimentMode {
                Text("(\(connectivity.currentExperimentMode))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var exportButton: some View {
        Button(action: {
            if let url = connectivity.exportLogs() {
                // Share the CSV file
                let activityVC = UIActivityViewController(
                    activityItems: [url],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }
        }) {
            Label("Export Logs", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if let badge = badge {
                Text(badge)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ExperimentSettingsView: View {
    @Binding var experimentMode: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    
    let modes = [
        ("directTouch", "Direct Touch", "hand.tap"),
        ("pinch", "Pinch Gesture", "hand.pinch"),
        ("phonaze", "Phonaze Control", "iphone")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Experiment Mode")
                    .font(.headline)
                    .padding()
                
                ForEach(modes, id: \.0) { mode in
                    Button(action: {
                        experimentMode = mode.0
                    }) {
                        HStack {
                            Image(systemName: mode.2)
                                .font(.title2)
                                .frame(width: 40)
                            
                            Text(mode.1)
                                .font(.body)
                            
                            Spacer()
                            
                            if experimentMode == mode.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(
                            experimentMode == mode.0 ?
                            Color.blue.opacity(0.1) :
                            Color(.systemGray6)
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("Start Experiment") {
                    onConfirm()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .navigationTitle("Experiment Settings")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }
            )
        }
    }
}
