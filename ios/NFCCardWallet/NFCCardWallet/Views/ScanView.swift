import SwiftUI
import SwiftData

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var reader = NFCReader()
    @State private var savedCardId: UUID?
    @State private var showSavedToast = false
    @State private var nextColorIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(reader.isScanning ? "正在扫描..." : "将卡片靠近 iPhone")
                    .font(.title2.bold())
                Text("把 NFC 卡片贴到 iPhone 背部上方\n直到听到提示音")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.18), lineWidth: 6)
                        .frame(width: 200, height: 200)
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(reader.isScanning ? 360 : 0))
                        .animation(reader.isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: reader.isScanning)
                    Image(systemName: reader.lastResult == nil ? "wave.3.right" : "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(reader.lastResult == nil ? .gray.opacity(0.6) : .green)
                }
                .padding(.top, 8)

                if let result = reader.lastResult {
                    resultCard(result)
                        .transition(.scale.combined(with: .opacity))
                }

                if let err = reader.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        reader.startScanning()
                    } label: {
                        Label(reader.lastResult == nil ? "开始扫描" : "重新扫描",
                              systemImage: "wave.3.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(reader.isScanning)
                    .opacity(reader.isScanning ? 0.6 : 1)

                    if reader.lastResult != nil {
                        Button {
                            saveCard()
                        } label: {
                            Label("保存到卡片库", systemImage: "tray.and.arrow.down.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("扫描 NFC")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if showSavedToast {
                    Text("已保存到卡片库")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 40)
                }
            }
            .onAppear {
                updateColorIndex()
            }
        }
    }

    private func resultCard(_ result: NFCReader.ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("读取结果")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            infoRow("UID", result.uidHex)
            infoRow("类型", result.cardType)
            infoRow("SAK", result.sakHex)
            infoRow("ATQA", result.atqaHex)
            infoRow("NDEF", result.ndefInfo)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .foregroundStyle(.secondary)
            Spacer()
            Text(v)
                .font(.callout.monospaced())
                .foregroundStyle(.blue)
        }
        .font(.subheadline)
    }

    private func saveCard() {
        guard let result = reader.lastResult else { return }
        let card = NFCCard(
            name: "卡片 #\(Date().formatted(.dateTime.hour().minute()))",
            uidHex: result.uidHex,
            cardType: result.cardType,
            sakHex: result.sakHex,
            atqaHex: result.atqaHex,
            ndefInfo: result.ndefInfo,
            colorIndex: nextColorIndex
        )
        modelContext.insert(card)
        try? modelContext.save()
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
        reader.lastResult = nil
        updateColorIndex()
    }

    private func updateColorIndex() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<NFCCard>())) ?? 0
        nextColorIndex = count
    }
}

#Preview {
    ScanView()
        .modelContainer(for: NFCCard.self, inMemory: true)
}
