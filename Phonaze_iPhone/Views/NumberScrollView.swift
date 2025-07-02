import SwiftUI

struct NumberScrollView: View {
    @EnvironmentObject var connectivityManager: ConnectivityManager
    
    // 스크롤할 숫자 목록
    let numbers = Array(1...50)
    
    // 현재 “중앙”에 있는 숫자
    @State private var selectedNumber: Int? = nil
    
    // “내가 보낸 스크롤”인지, “상대방에서 온 스크롤”인지 구분하기 위한 플래그
    @State private var isRemoteScrolling: Bool = false
    
    // 너무 자주 ‘중앙 변경’ 이벤트가 발생하지 않도록 방지
    @State private var recentlyUpdatedCenter: Bool = false
    
    // ScrollViewReader에서 스크롤 위치를 제어할 때 사용
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SelectView (iPhone)")
                .font(.largeTitle)
                .bold()
            
            Text("스크롤하면 VisionOS도 따라가게 만들기")
                .foregroundColor(.secondary)
            
            // 실제 스크롤 영역
            GeometryReader { outerGeo in
                ScrollView(.vertical, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 20) {
                            ForEach(numbers, id: \.self) { num in
                                Text("\(num)")
                                    .font(.title3).bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(8)
                                    .id(num)
                                    .background(
                                        // 각 항목이 중앙 근처인지 추적
                                        GeometryReader { itemGeo in
                                            Color.clear
                                                .onAppear {
                                                    checkCenterPosition(num, itemGeo, outerGeo)
                                                }
                                                .onChange(of: itemGeo.frame(in: .named("scrollArea"))) { _ in
                                                    checkCenterPosition(num, itemGeo, outerGeo)
                                                }
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .onAppear {
                            scrollProxy = proxy
                        }
                    }
                }
                .coordinateSpace(name: "scrollArea") // 중앙 계산용
            }
            .frame(height: 400)
            
            Spacer()
        }
        .padding()
        // Vision → iPhone 메시지 수신
        .onChange(of: connectivityManager.receivedMessage) { newMessage in
            processMessage(newMessage)
        }
    }
}

// MARK: - 내부 로직
extension NumberScrollView {
    
    /// VisionOS에서 보낸 SCROLL_SELECT:XX 메시지 처리
    private func processMessage(_ message: String) {
        if message.hasPrefix("SCROLL_SELECT:") {
            if let data = message.split(separator: ":").last,
               let number = Int(data.trimmingCharacters(in: .whitespaces)) {
                // 원격 스크롤 동작 (iPhone도 해당 숫자로 이동)
                scrollToNumber(number)
            }
        }
    }
    
    /// iPhone이 특정 숫자로 스크롤
    private func scrollToNumber(_ number: Int) {
        guard let proxy = scrollProxy else { return }
        guard numbers.contains(number) else { return }
        
        isRemoteScrolling = true
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(number, anchor: .center)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRemoteScrolling = false
        }
    }
    
    /// 화면 중앙 근처에 있는 숫자 감지
    private func checkCenterPosition(_ num: Int,
                                     _ itemGeo: GeometryProxy,
                                     _ containerGeo: GeometryProxy) {
        // “리모트 스크롤 중”에는 내 쪽에서 새 SCROLL_SELECT를 보내지 않음
        guard !isRemoteScrolling else { return }
        
        let frame = itemGeo.frame(in: .named("scrollArea"))
        let centerY = containerGeo.size.height / 2
        let tolerance: CGFloat = 20
        
        // 해당 숫자의 midY가 스크롤 뷰의 중앙 근처에 있는지
        if (frame.midY > centerY - tolerance) && (frame.midY < centerY + tolerance) {
            // 너무 잦은 이벤트 방지
            if recentlyUpdatedCenter { return }
            recentlyUpdatedCenter = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.recentlyUpdatedCenter = false
            }
            
            // 새로운 중앙 숫자
            selectedNumber = num
            
            // VisionOS에게 알림
            let message = "SCROLL_SELECT:\(num)"
            connectivityManager.sendMessage(message)
        }
    }
}
