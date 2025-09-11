//
//  ConnectivityManager.swift
//  Phonaze_iPhone
//
//  Created by YourName on 3/17/25.
//

import Foundation
import MultipeerConnectivity

// MARK: - Message Protocol (VisionPro와 동일)
enum WireMessage: Codable {
    case hello(Hello)
    case ping(Ping)
    case pong(Pong)
    case modeSet(ModeSet)
    case webTap(WebTap)
    case webScroll(WebScroll)
    case webHoverTap
    
    enum CodingKeys: String, CodingKey { case type, payload }
    enum Kind: String, Codable { case hello, ping, pong, modeSet, webTap, webScroll, webHoverTap}
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .hello:    self = .hello(try c.decode(Hello.self,    forKey: .payload))
        case .ping:     self = .ping( try c.decode(Ping.self,     forKey: .payload))
        case .pong:     self = .pong( try c.decode(Pong.self,     forKey: .payload))
        case .modeSet:  self = .modeSet(try c.decode(ModeSet.self,forKey: .payload))
        case .webTap:   self = .webTap(try c.decode(WebTap.self,  forKey: .payload))
        case .webScroll:self = .webScroll(try c.decode(WebScroll.self,forKey: .payload))
        case .webHoverTap: self = .webHoverTap
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let p):    try c.encode(Kind.hello,   forKey: .type); try c.encode(p, forKey: .payload)
        case .ping(let p):     try c.encode(Kind.ping,    forKey: .type); try c.encode(p, forKey: .payload)
        case .pong(let p):     try c.encode(Kind.pong,    forKey: .type); try c.encode(p, forKey: .payload)
        case .modeSet(let p):  try c.encode(Kind.modeSet, forKey: .type); try c.encode(p, forKey: .payload)
        case .webTap(let p):   try c.encode(Kind.webTap,  forKey: .type); try c.encode(p, forKey: .payload)
        case .webScroll(let p):try c.encode(Kind.webScroll,forKey: .type);try c.encode(p, forKey: .payload)
        case .webHoverTap:     try c.encode(Kind.webHoverTap, forKey: .type)
        }
    }
}

struct Hello: Codable {
    enum Role: String, Codable { case vision, iphone }
    struct Caps: Codable { var jsTap: Bool; var nativeScroll: Bool }
    let role: Role
    let version: Int
    let capabilities: Caps
    static let defaultCaps = Caps(jsTap: true, nativeScroll: true)
}

struct Ping: Codable { let t: TimeInterval }
struct Pong: Codable { let t: TimeInterval }
struct ModeSet: Codable { let mode: String }
struct WebTap: Codable { let nx: Double, ny: Double }
struct WebScroll: Codable { let dx: Double, dy: Double }

enum MessageCodec {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    static func encode(_ m: WireMessage) throws -> Data { try encoder.encode(m) }
    static func decode(_ d: Data) throws -> WireMessage { try decoder.decode(WireMessage.self, from: d) }
}

// MARK: - ConnectivityManager
/// iPhone(클라이언트) 측에서 Browser만 사용하여, Vision Pro(호스트) Advertiser를 발견 후
/// 초대를 보내어 연결을 맺는 구조입니다.
class ConnectivityManager: NSObject, ObservableObject {
    private let serviceType = "phonaze-service"
    
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?   // iPhone은 Browser만
    
    // 발견된 피어 목록, 연결 상태
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMessage: String = ""
    @Published var receivedWire: WireMessage?
    @Published var isConnected: Bool = false
    @Published var connectedPeerName: String? = nil
    @Published var currentMode: String = "directTouch"
    
    // MARK: - 실험 관련 추가 기능
    @Published var isExperimentMode: Bool = false
    @Published var currentExperimentMode: String = "directTouch"
    
    // 인터랙션 로깅
    private var interactionLogs: [InteractionLog] = []
    
    struct InteractionLog {
        let timestamp: Date
        let type: String
        let details: String
    }
    
    override init() {
        super.init()
        
        // 세션 초기화
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
        
        // Browser 초기화
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
    }
    
    /// 브라우징 시작 (호스트 광고를 찾기 시작)
    func startBrowsing() {
        browser?.startBrowsingForPeers()
    }
    
    /// 브라우징 중단 (원할 때 중지)
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
    }
    
    /// 발견된 피어를 초대하여 연결 시도
    func invitePeer(_ peerID: MCPeerID) {
        guard let session = session else { return }
        print("피어 초대 시도: \(peerID.displayName)")
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    // MARK: - Send Methods
    
    /// JSON 메시지 전송
    func sendWire(_ message: WireMessage) {
        guard let session = session else { return }
        do {
            let data = try MessageCodec.encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("Sent wire message: \(message)")
        } catch {
            print("sendWire error:", error.localizedDescription)
        }
    }
    
    /// 레거시 문자열 메시지 전송 (기존 호환성 유지)
    func sendMessage(_ message: String) {
        guard let session = session else { return }
        let data = Data(message.utf8)
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("Sent legacy message: \(message)")
            logInteraction(type: "message", details: message)
        } catch {
            print("메시지 전송 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Web Control Methods
    
    /// Web 탭 전송 (JSON)
    func sendWebTap(nx: Double, ny: Double) {
        sendWire(.webTap(.init(nx: nx, ny: ny)))
        logInteraction(type: "web_tap", details: "nx: \(nx), ny: \(ny)")
    }
    
    /// Web 스크롤 전송 (JSON)
    func sendWebScroll(dx: Double, dy: Double) {
        sendWire(.webScroll(.init(dx: dx, dy: dy)))
        logInteraction(type: "web_scroll", details: "dx: \(dx), dy: \(dy)")
    }
    
    /// 시선 기반 탭 전송
    func sendWebHoverTap() {
        print("iPhone: Sending webHoverTap")
        sendWire(.webHoverTap)
        logInteraction(type: "hover_tap", details: "Gaze-based tap sent")
    }
    
    /// 정밀 스크롤 전송
    func sendPrecisionScroll(dx: Double, dy: Double) {
        // 작은 단위로 나누어 전송
        let steps = 5
        let stepDx = dx / Double(steps)
        let stepDy = dy / Double(steps)
        
        for _ in 0..<steps {
            sendWebScroll(dx: stepDx, dy: stepDy)
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        logInteraction(type: "precision_scroll", details: "dx: \(dx), dy: \(dy)")
    }
    
    /// 제스처 기반 명령 전송
    func sendGestureCommand(_ gesture: String) {
        let message = "GESTURE:\(gesture)"
        sendMessage(message)
        logInteraction(type: "gesture", details: gesture)
    }
    
    /// 모드 변경 전송
    func sendModeChange(_ mode: String) {
        sendWire(.modeSet(.init(mode: mode)))
        currentMode = mode
        logInteraction(type: "mode_change", details: mode)
    }
    
    // MARK: - Navigation Commands
    
    func sendNavigationCommand(_ command: String) {
        let message = "WEB_NAV:\(command)"
        sendMessage(message)
        logInteraction(type: "navigation", details: command)
    }
    
    func sendURLCommand(_ url: String) {
        let message = "WEB_URL:\(url)"
        sendMessage(message)
        logInteraction(type: "url", details: url)
    }
    
    // MARK: - Experiment Mode
    
    func setExperimentMode(_ enabled: Bool, mode: String = "directTouch") {
        isExperimentMode = enabled
        currentExperimentMode = mode
        
        if enabled {
            sendMessage("EXP_MODE:ON:\(mode)")
            startLogging()
        } else {
            sendMessage("EXP_MODE:OFF")
            stopLogging()
        }
    }
    
    private func startLogging() {
        interactionLogs.removeAll()
        print("📊 Started experiment logging")
    }
    
    private func stopLogging() {
        _ = exportLogs()
        print("📊 Stopped experiment logging")
    }
    
    private func logInteraction(type: String, details: String) {
        guard isExperimentMode else { return }
        
        let log = InteractionLog(
            timestamp: Date(),
            type: type,
            details: details
        )
        interactionLogs.append(log)
    }
    
    // MARK: - Data Export
    
    func exportLogs() -> URL? {
        guard !interactionLogs.isEmpty else { return nil }
        
        var lines: [String] = []
        lines.append("timestamp,type,details")
        
        let formatter = ISO8601DateFormatter()
        for log in interactionLogs {
            let line = [
                formatter.string(from: log.timestamp),
                log.type,
                "\"\(log.details)\""
            ].joined(separator: ",")
            lines.append(line)
        }
        
        let filename = "iPhone_Interactions_\(Int(Date().timeIntervalSince1970)).csv"
        let text = lines.joined(separator: "\n")
        
        do {
            let dir = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let url = dir.appendingPathComponent(filename)
            try text.write(to: url, atomically: true, encoding: .utf8)
            print("📁 Exported: \(filename)")
            return url
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func handleWireMessage(_ wm: WireMessage) {
        switch wm {
        case .hello(let h):
            print("Received HELLO from \(h.role) v\(h.version)")
            
        case .ping(let p):
            // Ping 받으면 즉시 Pong 회신
            sendWire(.pong(.init(t: p.t)))
            
        case .pong(let p):
            let latency = Date().timeIntervalSince1970 - p.t
            print("PONG received, latency: \(latency)s")
            
        case .modeSet(let m):
            currentMode = m.mode
            currentExperimentMode = m.mode
            print("Mode changed to: \(m.mode)")
            
        default:
            print("Received wire message: \(wm)")
        }
    }
}

// MARK: - MCSessionDelegate
extension ConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.isConnected = !session.connectedPeers.isEmpty
            
            switch state {
            case .connected:
                self.connectedPeerName = peerID.displayName
                // 연결되면 자동으로 핸드셰이크
                self.sendWire(.hello(.init(
                    role: .iphone,
                    version: 1,
                    capabilities: Hello.defaultCaps
                )))
                
                // 선택적: Ping 테스트
                self.sendWire(.ping(.init(t: Date().timeIntervalSince1970)))
                
            case .notConnected:
                if self.connectedPeers.isEmpty {
                    self.connectedPeerName = nil
                }
                
            case .connecting:
                print("Connecting to: \(peerID.displayName)")
                
            @unknown default:
                break
            }
        }
        print("피어 \(peerID.displayName) 상태 변경: \(state.rawValue)")
    }
    
    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        // 1. JSON 메시지 우선 시도
        if let wm = try? MessageCodec.decode(data) {
            print("Received JSON message from \(peerID.displayName)")
            DispatchQueue.main.async {
                self.receivedWire = wm
                self.handleWireMessage(wm)
            }
            return
        }
        
        // 2. 레거시 문자열 메시지 처리
        let message = String(decoding: data, as: UTF8.self)
        print("iPhone이 받은 메시지: \"\(message)\" from \(peerID.displayName)")
        DispatchQueue.main.async {
            self.receivedMessage = message
            
            // 실험 상태 메시지 처리
            if message.hasPrefix("EXP_STATE:") {
                self.handleExperimentStateMessage(message)
            }
        }
    }
    
    private func handleExperimentStateMessage(_ message: String) {
        // EXP_STATE:FOCUS:id
        // EXP_STATE:TARGET:id
        // EXP_STATE:PHASE:phase
        // EXP_STATE:SCORE:n/goal
        // EXP_STATE:ERROR:count
        
        let components = message.split(separator: ":")
        guard components.count >= 2 else { return }
        
        switch components[1] {
        case "FOCUS":
            if components.count > 2 {
                print("Focus changed to: \(components[2])")
            }
        case "TARGET":
            if components.count > 2 {
                print("Target set to: \(components[2])")
            }
        case "PHASE":
            if components.count > 2 {
                print("Phase changed to: \(components[2])")
            }
        case "SCORE":
            if components.count > 2 {
                print("Score: \(components[2])")
            }
        case "ERROR":
            if components.count > 2 {
                print("Error count: \(components[2])")
            }
        default:
            break
        }
    }
    
    // 스트림/리소스 전송은 미사용
    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {}
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ConnectivityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        print("발견된 피어: \(peerID.displayName)")
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("피어 손실: \(peerID.displayName)")
        DispatchQueue.main.async {
            if let index = self.discoveredPeers.firstIndex(of: peerID) {
                self.discoveredPeers.remove(at: index)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("브라우징 시작 실패: \(error.localizedDescription)")
    }
}
