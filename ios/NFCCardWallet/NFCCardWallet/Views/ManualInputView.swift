import SwiftUI
import SwiftData

/// 手动输入卡信息表单
struct ManualInputView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 可选：扫码后预填的 UID
    var prefillUID: String? = nil
    /// 可选：扫码后预填的名称
    var prefillName: String? = nil

    @State private var name = ""
    @State private var uidHex = ""
    @State private var cardType = "MIFARE Ultralight"
    @State private var sakHex = ""
    @State private var atqaHex = ""
    @State private var ndefInfo = ""
    @State private var colorIndex = 0
    @State private var validationError: String?
    @State private var showSavedToast = false
    @State private var didApplyPrefill = false

    private let cardTypes = [
        "MIFARE Ultralight",
        "MIFARE Classic 1K",
        "MIFARE Classic 4K",
        "MIFARE DESFire",
        "MIFARE Plus",
        "FeliCa",
        "ISO15693",
        "ISO14443-4",
        "NTAG213",
        "NTAG215",
        "NTAG216",
        "其他"
    ]

    private let palette: [(Color, Color)] = [
        (Color(red: 0.17, green: 0.24, blue: 0.31), Color(red: 0.29, green: 0.40, blue: 0.25)),
        (Color(red: 0.56, green: 0.27, blue: 0.68), Color(red: 0.36, green: 0.17, blue: 0.53)),
        (Color(red: 0.75, green: 0.22, blue: 0.17), Color(red: 0.57, green: 0.17, blue: 0.13)),
        (Color(red: 0.06, green: 0.63, blue: 0.52), Color(red: 0.05, green: 0.40, blue: 0.33)),
        (Color(red: 0.16, green: 0.50, blue: 0.73), Color(red: 0.11, green: 0.31, blue: 0.45)),
        (Color(red: 0.83, green: 0.33, blue: 0.0), Color(red: 0.63, green: 0.25, blue: 0.0))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 卡面预览
                    cardPreview

                    // 基本信息分组
                    GroupBox("基本信息") {
                        VStack(spacing: 12) {
                            inputField(title: "卡片名称", text: $name, placeholder: "如：门禁卡", required: true)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            inputField(title: "UID (Hex)", text: $uidHex, placeholder: "如：04 A3 12 5F 7B 81", required: true)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("卡片类型")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Picker("卡片类型", selection: $cardType) {
                                    ForEach(cardTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // 高级信息分组
                    GroupBox("高级信息（可选）") {
                        VStack(spacing: 12) {
                            inputField(title: "SAK", text: $sakHex, placeholder: "如：0x00")
                                .textInputAutocapitalization(.never)
                            inputField(title: "ATQA", text: $atqaHex, placeholder: "如：0x4400")
                                .textInputAutocapitalization(.never)
                            inputField(title: "NDEF", text: $ndefInfo, placeholder: "如：有 (48B)")
                                .textInputAutocapitalization(.never)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("卡面颜色")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    ForEach(palette.indices, id: \.self) { i in
                                        let (c1, c2) = palette[i]
                                        LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.primary.opacity(colorIndex == i ? 0.8 : 0), lineWidth: 2)
                                            )
                                            .onTapGesture { colorIndex = i }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    if let err = validationError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        save()
                    } label: {
                        Label("保存到卡片库", systemImage: "tray.and.arrow.down.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("手动输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .overlay {
                if showSavedToast {
                    Text("已保存 ✓")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.green.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 20)
                }
            }
            .onAppear {
                if !didApplyPrefill {
                    didApplyPrefill = true
                    if let uid = prefillUID, !uid.isEmpty {
                        uidHex = uid
                    }
                    if let n = prefillName, !n.isEmpty {
                        name = n
                    }
                }
            }
        }
    }

    private var cardPreview: some View {
        let (c1, c2) = palette[colorIndex]
        return ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .offset(x: 60, y: -60),
                    alignment: .topTrailing
                )

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [.yellow, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 26)
                Text(name.isEmpty ? "卡片名称" : name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(uidHex.isEmpty ? "UID: --:--:--:--" : "UID: \(formattedUid(uidHex))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 110)
    }

    private func inputField(title: String, text: Binding<String>, placeholder: String, required: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if required {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func formattedUid(_ raw: String) -> String {
        let clean = raw.replacingOccurrences(of: " ", with: "").uppercased()
        var chunks: [String] = []
        var current = ""
        for ch in clean {
            current.append(ch)
            if current.count == 2 {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.joined(separator: ":")
    }

    private func save() {
        // 校验
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUid = uidHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationError = "请填写卡片名称"
            return
        }
        if trimmedUid.isEmpty {
            validationError = "请填写 UID"
            return
        }
        validationError = nil

        let card = NFCCard(
            name: trimmedName,
            uidHex: trimmedUid,
            cardType: cardType,
            sakHex: sakHex.isEmpty ? "—" : sakHex,
            atqaHex: atqaHex.isEmpty ? "—" : atqaHex,
            ndefInfo: ndefInfo.isEmpty ? "—" : ndefInfo,
            colorIndex: colorIndex
        )
        modelContext.insert(card)
        try? modelContext.save()

        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

#Preview {
    ManualInputView()
        .modelContainer(for: NFCCard.self, inMemory: true)
}
