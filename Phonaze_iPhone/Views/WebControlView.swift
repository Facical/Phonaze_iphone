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
            .simultaneousGesture(
                TapGesture()
                    .onEnded { location in
                        // TapGesture does not provide location, so use highPriorityGesture with DragGesture or onTapGesture with location
                    }
            )
            .onTapGesture { location in
                let xRatio = location.x / geo.size.width
                let yRatio = location.y / geo.size.height
                let message = String(format: "WEB_TAP:%.3f,%.3f", xRatio, yRatio)
                connectivityManager.sendMessage(message)
            }
        }
        .navigationTitle("WebControl")
        .ignoresSafeArea(edges: .bottom)
    }
}
