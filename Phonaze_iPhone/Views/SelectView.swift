//
//  SelectView.swift
//  Phonaze_iPhone
//
//  Created by 강형준 on 3/17/25.
//

import SwiftUI

struct SelectView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager
    
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.yellow.opacity(0.3)
                
                Text("Tap anywhere to Select an object\n(x:\(Int(tapPosition.x)), y:\(Int(tapPosition.y)))")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .onTapGesture { location in
                // location: 탭한 좌표 (GeometryReader 기준)
                tapPosition = location
                let xRatio = location.x / geo.size.width
                let yRatio = location.y / geo.size.height
                
                // Vision Pro 쪽으로 "SELECT:xRatio,yRatio" 형태의 메시지를 보낸다고 가정
                let message = "SELECT:\(xRatio),\(yRatio)"
                connectivityManager.sendMessage(message)
            }
        }
        .navigationTitle("SelectView")
    }
}

struct SelectView_Previews: PreviewProvider {
    static var previews: some View {
        SelectView()
            .environmentObject(ConnectivityManager())
    }
}
