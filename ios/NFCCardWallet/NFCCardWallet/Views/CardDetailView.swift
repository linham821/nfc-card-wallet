import SwiftUI
import SwiftData
import PassKit
import CoreImage.CIFilterBuiltins

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: NFCCard
    @StateObject private var passGen = PassGenerator()
    @State private var showingDeleteAlert = false
    @State private var showingAddWallet = false

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
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                qrCard
                infoCard
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("卡片详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("删除卡片", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteCard() }
        } message: {
            Text("确定删除「\(card.name)」？此操作不可撤销。")
        }
        .sheet(item: $passGen.previewPassData) { _ in
            AddWalletView(card: card, passGen: passGen)
        }
        .sheet(item: $passGen.passController) { wrapper in
            PassControllerRepresentable(controller: wrapper.controller)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [colors.bg, colors.bg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .offset(x: 60, y: -60)
                , alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.yellow, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 32)

                Text(card.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("UID: \(card.uidDisplay)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 160)
    }

    private var qrCard: some View {
        VStack(spacing: 12) {
            if let image = generateQRCode(from: card.cardNumber) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView()
                    .frame(width: 160, height: 160)
            }
            Text("UID 二维码（用于扫码门禁）")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            row("卡片类型", card.cardType)
            row("SAK", card.sakHex)
            row("ATQA", card.atqaHex)
            row("读取时间", card.scannedAtDisplay)
            row("已加到钱包", card.addedToWallet ? "是" : "否")
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .foregroundStyle(.secondary)
            Spacer()
            Text(v)
                .font(.callout.monospaced())
        }
        .font(.subheadline)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .overlay(Divider(), alignment: .bottom)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                passGen.addCardToWallet(card)
            } label: {
                Label(card.addedToWallet ? "已在钱包中" : "加入 Apple Wallet",
                      systemImage: "wallet.pass.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .disabled(card.addedToWallet || passGen.isLoading)

            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("删除卡片", systemImage: "trash")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func deleteCard() {
        modelContext.delete(card)
        try? modelContext.save()
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.message = data
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: NFCCard(
            name: "示例卡",
            uidHex: "04 A3 12 5F 7B 81",
            cardType: "MIFARE Ultralight",
            sakHex: "0x00",
            atqaHex: "0x4400",
            ndefInfo: "有 (48B)"
        ))
    }
    .modelContainer(for: NFCCard.self, inMemory: true)
}

/// UIViewControllerRepresentable 包装 PKAddPassesViewController 用于 SwiftUI sheet
struct PassControllerRepresentable: UIViewControllerRepresentable {
    let controller: PKAddPassesViewController

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}
}
