import SwiftUI

enum AppTab {
    case history
    case analytics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .history
    @State private var showingAddSpend = false
    
    @AppStorage("triggerQuickAdd") private var triggerQuickAdd = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            VStack {
                if selectedTab == .history {
                    HistoryView()
                } else {
                    AnalyticsView()
                }
            }
            .padding(.bottom, 70)
            
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    Spacer()
                    TabBarButton(icon: "list.bullet.rectangle", title: "History", isSelected: selectedTab == .history) { selectedTab = .history }
                    Spacer()
                    Button(action: { showingAddSpend = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "dot.radiowaves.up.forward").font(.system(size: 24, weight: .bold))
                            Text("Tap").font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.bottom, 5)
                    Spacer()
                    TabBarButton(icon: "chart.line.uptrend.xyaxis", title: "Analytics", isSelected: selectedTab == .analytics) { selectedTab = .analytics }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(Color.black.ignoresSafeArea())
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showingAddSpend) { AddSpendView() }
        // FIX 1: Listens while app is running
        .onChange(of: triggerQuickAdd) { _, newValue in
            if newValue { openAddSpend() }
        }
        // FIX 2: Listens when app first boots up
        .onAppear {
            if triggerQuickAdd { openAddSpend() }
        }
    }
    
    private func openAddSpend() {
        showingAddSpend = true
        triggerQuickAdd = false // Reset immediately
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22))
                Text(title).font(.caption2)
            }
            .foregroundColor(isSelected ? .white : .gray)
        }
    }
}
