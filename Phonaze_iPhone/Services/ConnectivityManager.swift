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
    
    enum CodingKeys: String, CodingKey { case type, payload }
    enum Kind: String, Codable { case hello, ping, pong, modeSet, webTap, webScroll }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .hello:    self = .hello(try c.decode(Hello.self,    forKey: .payload))
        case .ping:     self = .ping( try c.decode(Ping.self,     forKey: .payload))
        case .pong:     self = .pong( try c.decode(Pong.self,     forKey: .payload))
        case .modeSet:  self = .modeSet(try c.decode(ModeSet.self,forKey: .payload))
        case .webTap:   self = .webTap(try c.decode(WebTap.self,  forKey: .payload))
        case .webScroll:self = .webScroll(try c.decode(WebScroll.self,forKey: .payload))
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
    @Published var currentMode: String = "directTouch"
    
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
        } catch {
            print("메시지 전송 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Web Control Methods
    
    /// Web 탭 전송 (JSON)
    func sendWebTap(nx: Double, ny: Double) {
        sendWire(.webTap(.init(nx: nx, ny: ny)))
    }
    
    /// Web 스크롤 전송 (JSON)
    func sendWebScroll(dx: Double, dy: Double) {
        sendWire(.webScroll(.init(dx: dx, dy: dy)))
    }
    
    /// 모드 변경 전송
    func sendModeChange(_ mode: String) {
        sendWire(.modeSet(.init(mode: mode)))
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
            
            if state == .connected {
                // 연결되면 자동으로 핸드셰이크
                self.sendWire(.hello(.init(
                    role: .iphone,
                    version: 1,
                    capabilities: Hello.defaultCaps
                )))
                
                // 선택적: Ping 테스트
                self.sendWire(.ping(.init(t: Date().timeIntervalSince1970)))
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
