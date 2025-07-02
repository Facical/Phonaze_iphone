//
//  ConnectivityManager.swift
//  Phonaze_iPhone
//
//  Created by YourName on 3/17/25.
//

import Foundation
import MultipeerConnectivity

/// iPhone(클라이언트) 측에서 Browser만 사용하여, Vision Pro(호스트) Advertiser를 발견 후
/// 초대를 보내어 연결을 맺는 구조입니다. Advertiser 코드는 제거했습니다.
class ConnectivityManager: NSObject, ObservableObject {
    private let serviceType = "phonaze-service"
    
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?   // iPhone은 Browser만
    
    // 발견된 피어 목록, 연결 상태
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMessage: String = ""
    @Published var isConnected: Bool = false
    
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
    
    /// 연결된 피어에게 메시지 전송
    func sendMessage(_ message: String) {
        guard let session = session else { return }
        let data = Data(message.utf8)
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("메시지 전송 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCSessionDelegate
extension ConnectivityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.isConnected = !session.connectedPeers.isEmpty
        }
        print("피어 \(peerID.displayName) 상태 변경: \(state.rawValue)")
    }
    
    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
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
