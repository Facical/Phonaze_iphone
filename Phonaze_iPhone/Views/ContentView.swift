// Phonaze_iPhone/Views/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = ConnectivityManager()
    @State private var hasConnected = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 앱 로고/타이틀
                VStack(spacing: 8) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Phonaze Controller")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Vision Pro Remote Control")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // 연결 버튼
                if !connectivityManager.isConnected {
                    ConnectionButton(connectivityManager: connectivityManager)
                } else {
                    // 연결됨 - HomeView로 자동 이동
                    NavigationLink(
                        destination: HomeView()
                            .environmentObject(connectivityManager),
                        isActive: $hasConnected
                    ) {
                        EmptyView()
                    }
                    .onAppear {
                        hasConnected = true
                    }
                    
                    ConnectedStatusView(connectivityManager: connectivityManager)
                }
                
                Spacer()
                
                // 하단 정보
                VStack(spacing: 4) {
                    Text("Experiment Mode Available")
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Text("v1.1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
        .environmentObject(connectivityManager)
        .onAppear {
            // 자동으로 브라우징 시작
            connectivityManager.startBrowsing()
        }
    }
}

struct ConnectionButton: View {
    @ObservedObject var connectivityManager: ConnectivityManager
    
    var body: some View {
        VStack(spacing: 16) {
            if connectivityManager.discoveredPeers.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Searching for Vision Pro...")
                    .font(.headline)
            } else {
                ForEach(connectivityManager.discoveredPeers, id: \.self) { peer in
                    Button(action: {
                        connectivityManager.invitePeer(peer)
                    }) {
                        HStack {
                            Image(systemName: "visionpro")
                                .font(.title2)
                            
                            Text(peer.displayName)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("Tap to Connect")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ConnectedStatusView: View {
    @ObservedObject var connectivityManager: ConnectivityManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Connected!")
                .font(.title2)
                .bold()
            
            Text(connectivityManager.connectedPeerName ?? "Vision Pro")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
