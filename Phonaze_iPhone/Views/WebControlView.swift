import SwiftUI

struct WebControlView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager
    @State private var lastDragValue: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6)
                Text("Web Control Mode\nTouch: Click, Drag: Scroll")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        let dx = Int(value.translation.width)
                        let dy = Int(value.translation.height)
                        let message = "WEB_SCROLL:\(dx),\(dy)"
                        connectivityManager.sendMessage(message)
                        lastDragValue = .zero
                    }
            )
            .onTapGesture {
                connectivityManager.sendMessage("WEB_TAP")
            }
        }
        .navigationTitle("WebControl")
        .ignoresSafeArea(edges: .bottom)
    }
}
