import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NFCCard.scannedAt, order: .reverse) private var cards: [NFCCard]
    @State private var showingDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(cards) { card in
                                NavigationLink(value: card) {
                                    CardRowView(card: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("我的卡片")
            .navigationDestination(for: NFCCard.self) { card in
                CardDetailView(card: card)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.gray.opacity(0.4))
            Text("还没有卡片")
                .font(.title3.bold())
            Text("切到「添加」Tab 手动输入、扫码或导入 JSON")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

struct CardRowView: View {
    let card: NFCCard

    private var colors: (bg: Color, bg2: Color) {
        let palette: [(Color, Color)] = [
            (Color(red: 0.17, green: 0.24, blue: 0.31), Color(red: 0.29, green: 0.40, blue: 0.25)),
            (Color(red: 0.56, green: 0.27, blue: 0.68), Color(red: 0.36, green: 0.17, blue: 0.53)),
            (Color(red: 0.75, green: 0.22, blue: 0.17), Color(red: 0.57, green: 0.17, blue: 0.13)),
            (Color(red: 0.06, green: 0.63, blue: 0.52), Color(red: 0.05, green: 0.40, blue: 0.33)),
            (Color(red: 0.16, green: 0.50, blue: 0.73), Color(red: 0.11, green: 0.31, blue: 0.45)),
            (Color(red: 0.83, green: 0.33, blue: 0.0), Color(red: 0.63, green: 0.25, blue: 0.0))
        ]
        return palette[card.colorIndex % palette.count]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [colors.bg, colors.bg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .offset(x: 60, y: -60)
                , alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardType)
                    .font(.caption2.weight(.medium))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.75))

                Text(card.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("UID: \(card.uidDisplay)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if card.addedToWallet {
                Text("✓ 已加钱包")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
                    .padding(12)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
}

#Preview {
    CardListView()
        .modelContainer(for: NFCCard.self, inMemory: true)
}
