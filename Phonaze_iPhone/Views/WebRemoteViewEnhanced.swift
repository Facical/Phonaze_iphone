// Phonaze_iPhone/Views/WebRemoteViewEnhanced.swift

import SwiftUI
import UIKit

struct WebRemoteViewEnhanced: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager
    
    // Control states
    @State private var controlMode: ControlMode = .touchpad
    @State private var isRecordingGesture = false
    
    // Touchpad states
    @State private var lastTouchPoint: CGPoint? = nil
    @State private var touchStartTime: Date? = nil
    @State private var totalDragDistance: CGFloat = 0
    
    // Gesture recording
    @State private var gesturePoints: [CGPoint] = []
    @State private var gestureStartTime: Date? = nil
    
    // Settings
    @State private var scrollSensitivity: CGFloat = 1.5
    @State private var tapFeedbackEnabled: Bool = true
    @State private var showSettings: Bool = false
    
    // Haptic generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    enum ControlMode: String, CaseIterable {
        case touchpad = "Touchpad"
        case gesture = "Gesture"
        case precision = "Precision"
        
        var icon: String {
            switch self {
            case .touchpad: return "hand.draw"
            case .gesture: return "scribble"
            case .precision: return "target"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with mode selector
            headerView
            
            // Main control area
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Control surface based on mode
                switch controlMode {
                case .touchpad:
                    touchpadView
                case .gesture:
                    gestureView
                case .precision:
                    precisionView
                }
            }
            
            // Quick action buttons
            quickActionsBar
        }
        .navigationTitle("Web Remote Enhanced")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                scrollSensitivity: $scrollSensitivity,
                tapFeedbackEnabled: $tapFeedbackEnabled
            )
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ControlMode.allCases, id: \.self) { mode in
                    Button(action: {
                        controlMode = mode
                        impactLight.impactOccurred()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                            Text(mode.rawValue)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 50)
                        .foregroundColor(controlMode == mode ? .white : .primary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(controlMode == mode ? Color.blue : Color.gray.opacity(0.2))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 70)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Touchpad Mode
    
    private var touchpadView: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid overlay for visual feedback
                GridOverlay()
                
                // Touch detection area
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleTouchpadDrag(value, in: geometry)
                            }
                            .onEnded { value in
                                handleTouchpadEnd(value, in: geometry)
                            }
                    )
                
                // Visual feedback for touch
                if let touchPoint = lastTouchPoint {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .position(touchPoint)
                        .animation(.easeOut(duration: 0.1), value: touchPoint)
                }
                
                // Center indicator
                Image(systemName: "viewfinder")
                    .font(.system(size: 30))
                    .foregroundColor(.gray.opacity(0.3))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
    
    private func handleTouchpadDrag(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        let current = value.location
        
        // Initialize on first touch
        if lastTouchPoint == nil {
            touchStartTime = Date()
            totalDragDistance = 0
        }
        
        // Calculate movement delta
        if let previous = lastTouchPoint {
            let dx = (current.x - previous.x) * scrollSensitivity
            let dy = (current.y - previous.y) * scrollSensitivity
            
            // Track total distance for tap detection
            totalDragDistance += hypot(dx, dy)
            
            // Send scroll command
            if abs(dx) > 0.5 || abs(dy) > 0.5 {
                connectivityManager.sendWebScroll(dx: dx, dy: dy)
                
                // Haptic feedback for scrolling
                if tapFeedbackEnabled {
                    selectionFeedback.selectionChanged()
                }
            }
        }
        
        lastTouchPoint = current
    }
    
    private func handleTouchpadEnd(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        let endPoint = value.location
        
        // Check if it's a tap (minimal movement and short duration)
        if totalDragDistance < 10 {
            if let startTime = touchStartTime {
                let duration = Date().timeIntervalSince(startTime)
                if duration < 0.3 {
                    // It's a tap - send hover tap
                    connectivityManager.sendWebHoverTap()
                    
                    if tapFeedbackEnabled {
                        impactMedium.impactOccurred()
                    }
                    
                    // Visual feedback
                    showTapFeedback(at: endPoint)
                }
            }
        }
        
        // Reset states
        lastTouchPoint = nil
        touchStartTime = nil
        totalDragDistance = 0
    }
    
    // MARK: - Gesture Mode
    
    private var gestureView: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas for drawing gestures
                Path { path in
                    guard !gesturePoints.isEmpty else { return }
                    path.move(to: gesturePoints[0])
                    for point in gesturePoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.blue, lineWidth: 3)
                
                // Gesture detection area
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isRecordingGesture {
                                    isRecordingGesture = true
                                    gestureStartTime = Date()
                                    gesturePoints = []
                                }
                                gesturePoints.append(value.location)
                            }
                            .onEnded { _ in
                                recognizeGesture()
                                isRecordingGesture = false
                            }
                    )
                
                // Instructions
                if gesturePoints.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Draw gestures to control")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 30) {
                            GestureHint(symbol: "↑", label: "Scroll Up")
                            GestureHint(symbol: "↓", label: "Scroll Down")
                            GestureHint(symbol: "○", label: "Tap")
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
    
    private func recognizeGesture() {
        guard !gesturePoints.isEmpty else { return }
        
        // Simple gesture recognition
        let startY = gesturePoints.first!.y
        let endY = gesturePoints.last!.y
        let deltaY = endY - startY
        
        if abs(deltaY) > 50 {
            // Vertical swipe
            if deltaY > 0 {
                // Swipe down = scroll down
                connectivityManager.sendWebScroll(dx: 0, dy: 200)
            } else {
                // Swipe up = scroll up
                connectivityManager.sendWebScroll(dx: 0, dy: -200)
            }
        } else if gesturePoints.count < 10 {
            // Short gesture = tap
            connectivityManager.sendWebHoverTap()
        }
        
        // Clear gesture
        withAnimation(.easeOut(duration: 0.3)) {
            gesturePoints = []
        }
        
        impactLight.impactOccurred()
    }
    
    // MARK: - Precision Mode
    
    private var precisionView: some View {
        VStack(spacing: 20) {
            // D-pad for precise scrolling
            DPadControl { direction in
                handleDPadInput(direction)
            }
            
            // Tap button
            Button(action: {
                connectivityManager.sendWebHoverTap()
                impactMedium.impactOccurred()
            }) {
                Text("TAP")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 150, height: 60)
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            
            // Fine scroll controls
            HStack(spacing: 40) {
                ScrollButton(direction: .left) {
                    connectivityManager.sendWebScroll(dx: -50, dy: 0)
                }
                ScrollButton(direction: .right) {
                    connectivityManager.sendWebScroll(dx: 50, dy: 0)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Quick Actions Bar
    
    private var quickActionsBar: some View {
        HStack(spacing: 20) {
            QuickActionButton(icon: "arrow.left", label: "Back") {
                connectivityManager.sendMessage("WEB_NAV:BACK")
            }
            
            QuickActionButton(icon: "arrow.clockwise", label: "Reload") {
                connectivityManager.sendMessage("WEB_NAV:RELOAD")
            }
            
            QuickActionButton(icon: "house", label: "Home") {
                connectivityManager.sendMessage("WEB_NAV:HOME")
            }
            
            QuickActionButton(icon: "magnifyingglass", label: "Search") {
                connectivityManager.sendMessage("WEB_NAV:SEARCH")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Helper Functions
    
    private func showTapFeedback(at point: CGPoint) {
        // This would show a visual tap indicator
        // Implementation depends on your UI framework
    }
    
    private func handleDPadInput(_ direction: DPadDirection) {
        switch direction {
        case .up:
            connectivityManager.sendWebScroll(dx: 0, dy: -100)
        case .down:
            connectivityManager.sendWebScroll(dx: 0, dy: 100)
        case .left:
            connectivityManager.sendWebScroll(dx: -100, dy: 0)
        case .right:
            connectivityManager.sendWebScroll(dx: 100, dy: 0)
        case .center:
            connectivityManager.sendWebHoverTap()
        }
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Supporting Views

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let rows = 10
                let cols = 10
                let rowHeight = geometry.size.height / CGFloat(rows)
                let colWidth = geometry.size.width / CGFloat(cols)
                
                // Horizontal lines
                for i in 0...rows {
                    path.move(to: CGPoint(x: 0, y: CGFloat(i) * rowHeight))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: CGFloat(i) * rowHeight))
                }
                
                // Vertical lines
                for i in 0...cols {
                    path.move(to: CGPoint(x: CGFloat(i) * colWidth, y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(i) * colWidth, y: geometry.size.height))
                }
            }
            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        }
    }
}

struct GestureHint: View {
    let symbol: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 24, weight: .bold))
            Text(label)
                .font(.caption2)
        }
        .foregroundColor(.gray)
    }
}

struct DPadControl: View {
    let onDirection: (DPadDirection) -> Void
    
    var body: some View {
        ZStack {
            // D-pad background
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 200)
            
            // Direction buttons
            VStack(spacing: 0) {
                DPadButton(direction: .up, onTap: onDirection)
                HStack(spacing: 0) {
                    DPadButton(direction: .left, onTap: onDirection)
                    DPadButton(direction: .center, onTap: onDirection)
                    DPadButton(direction: .right, onTap: onDirection)
                }
                DPadButton(direction: .down, onTap: onDirection)
            }
        }
    }
}

struct DPadButton: View {
    let direction: DPadDirection
    let onTap: (DPadDirection) -> Void
    
    var body: some View {
        Button(action: { onTap(direction) }) {
            Image(systemName: direction.icon)
                .font(.system(size: 24))
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(direction == .center ? 30 : 10)
        }
    }
}

enum DPadDirection {
    case up, down, left, right, center
    
    var icon: String {
        switch self {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .center: return "circle.fill"
        }
    }
}

struct ScrollButton: View {
    enum Direction {
        case left, right
        var icon: String {
            switch self {
            case .left: return "chevron.left.2"
            case .right: return "chevron.right.2"
            }
        }
    }
    
    let direction: Direction
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: direction.icon)
                .font(.title2)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(15)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SettingsView: View {
    @Binding var scrollSensitivity: CGFloat
    @Binding var tapFeedbackEnabled: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Control Settings") {
                    VStack(alignment: .leading) {
                        Text("Scroll Sensitivity: \(String(format: "%.1f", scrollSensitivity))")
                        Slider(value: $scrollSensitivity, in: 0.5...3.0, step: 0.1)
                    }
                    
                    Toggle("Haptic Feedback", isOn: $tapFeedbackEnabled)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}
