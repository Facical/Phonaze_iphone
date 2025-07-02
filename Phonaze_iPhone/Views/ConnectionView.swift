//
//  ConnectionView.swift
//  Phonaze_iPhone
//
//  Created by 강형준 on 3/17/25.
//

import SwiftUI
import MultipeerConnectivity

struct ConnectionView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager
    
    var body: some View {
        VStack {
            Text("Select a device to connect:")
                .font(.headline)
                .padding(.top, 20)
            
            List {
                ForEach(connectivityManager.discoveredPeers, id: \.self) { peerID in
                    HStack {
                        Text(peerID.displayName)
                        Spacer()
                        Button("Connect") {
                            connectivityManager.invitePeer(peerID)
                        }
                    }
                }
            }
            
            if connectivityManager.isConnected {
                Text("Connected to: \(connectivityManager.connectedPeers.map { $0.displayName }.joined(separator: ", "))")
                    .foregroundColor(.green)
                    .padding()
                
                NavigationLink(destination: HomeView()) {
                    Text("Go to Next Step")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            } else {
                Text("Not connected yet")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Connection")
        .onAppear {
            // iPhone은 Browser만 쓰므로, 브라우징 시작
            connectivityManager.startBrowsing()
        }
        .onDisappear {
            // 화면 떠날 때 브라우징 중단 (원하면 유지해도 됨)
            connectivityManager.stopBrowsing()
        }
    }
}

struct ConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionView()
            .environmentObject(ConnectivityManager())
    }
}
