import SwiftUI
import SwiftData

@main
struct NFCCardWalletApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: NFCCard.self)
    }
}

struct RootView: View {
    @State private var selection: Tab = .list

    enum Tab: Hashable {
        case list, scan, wallet
    }

    var body: some View {
        TabView(selection: $selection) {
            CardListView()
                .tabItem {
                    Label("卡片", systemImage: "creditcard.fill")
                }
                .tag(Tab.list)

            ScanView()
                .tabItem {
                    Label("扫描", systemImage: "wave.3.right.circle.fill")
                }
                .tag(Tab.scan)

            WalletInfoView()
                .tabItem {
                    Label("钱包", systemImage: "wallet.pass.fill")
                }
                .tag(Tab.wallet)
        }
        .tint(.blue)
    }
}

struct WalletInfoView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.gray.opacity(0.5))
                Text("钱包")
                    .font(.title2.bold())
                Text("在「卡片详情」页点击「加入 Apple Wallet」即可把卡片作为通用 Pass 添加到系统钱包 App。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .navigationTitle("钱包")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: NFCCard.self, inMemory: true)
}
