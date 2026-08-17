import SwiftUI
import SwiftData

struct AddWalletView: View {
    @Bindable var card: NFCCard
    @ObservedObject var passGen: PassGenerator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    passPreview

                    if confirmed {
                        VStack(spacing: 10) {
                            Label("已模拟加入 Wallet", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.green.opacity(0.1))
                                .clipShape(Capsule())

                            Text("注：在 App 内此步骤为「预览模式」。真机要真正加到系统钱包，需要按 README 中的步骤用 Pass Type ID 证书签名 .pkpass，然后由 PKAddPassesViewController 接管。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            confirmAdd()
                        } label: {
                            Label(confirmed ? "已添加 ✓" : "确认添加", systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .disabled(confirmed)

                        Button {
                            dismiss()
                        } label: {
                            Text("关闭")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("加入钱包")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var passPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NFC Card Wallet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(card.cardType)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(card.name)
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("UID: \(card.uidDisplay)")
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.7))

            // 模拟 Pass 的中间条
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(height: 30)
                .padding(.horizontal, -16)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("卡号")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(card.cardNumber)
                        .font(.callout.monospaced())
                        .foregroundStyle(.white)
                }
                Spacer()
                if let image = generateQRCode(from: card.cardNumber) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .padding(2)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(16)
        .background(passGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .padding(.horizontal, 20)
    }

    private var passGradient: LinearGradient {
        let palette: [(Color, Color)] = [
            (Color(red: 0.17, green: 0.24, blue: 0.31), Color(red: 0.29, green: 0.40, blue: 0.25)),
            (Color(red: 0.56, green: 0.27, blue: 0.68), Color(red: 0.36, green: 0.17, blue: 0.53)),
            (Color(red: 0.75, green: 0.22, blue: 0.17), Color(red: 0.57, green: 0.17, blue: 0.13)),
            (Color(red: 0.06, green: 0.63, blue: 0.52), Color(red: 0.05, green: 0.40, blue: 0.33)),
            (Color(red: 0.16, green: 0.50, blue: 0.73), Color(red: 0.11, green: 0.31, blue: 0.45)),
            (Color(red: 0.83, green: 0.33, blue: 0.0), Color(red: 0.63, green: 0.25, blue: 0.0))
        ]
        let (c1, c2) = palette[card.colorIndex % palette.count]
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func confirmAdd() {
        card.addedToWallet = true
        try? modelContext.save()
        withAnimation { confirmed = true }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
