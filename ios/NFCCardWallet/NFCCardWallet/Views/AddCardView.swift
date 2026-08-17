import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 添加卡片入口：手动输入 / 扫码识别 / JSON 导入
struct AddCardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingManualInput = false
    @State private var showingQRScanner = false
    @State private var showingJSONPicker = false
    @State private var showingImportPass = false
    @State private var prefillUID: String?
    @State private var prefillName: String?
    @State private var showingPrefilledManual = false
    @State private var toast: String?
    @State private var toastError = false

    private let jsonType = UTType(filenameExtension: "json") ?? UTType.json

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero

                    // 主要入口
                    VStack(spacing: 12) {
                        Button {
                            showingManualInput = true
                        } label: {
                            entryCard(
                                icon: "square.and.pencil",
                                title: "手动输入",
                                subtitle: "填写卡片名称、UID、类型等",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingQRScanner = true
                        } label: {
                            entryCard(
                                icon: "qrcode.viewfinder",
                                title: "扫描二维码/条码",
                                subtitle: "用摄像头识别卡面上的码",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingJSONPicker = true
                        } label: {
                            entryCard(
                                icon: "square.stack.up.badge.fill",
                                title: "导入 JSON",
                                subtitle: "批量导入卡片数据（支持数组）",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingImportPass = true
                        } label: {
                            entryCard(
                                icon: "wallet.pass.fill",
                                title: "导入 .pkpass 加入 Wallet",
                                subtitle: "加载已签名 Pass 文件到系统钱包",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    // 帮助说明
                    GroupBox("关于此 App") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("为什么没有 NFC 扫描？")
                                .font(.subheadline.bold())
                            Text("iOS 限制：使用 NFC Reader Session 需要付费 Apple Developer Program（$99/年）会员资格。本 App 通过 Sideloadly 用免费 Apple ID 签名，无法获取 NFC entitlement，故改为手动/扫码/导入方式录入卡片信息。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Divider().padding(.vertical, 4)

                            Text("如何加入 Apple Wallet？")
                                .font(.subheadline.bold())
                            Text("1. 在「卡片详情」点「导出 pass.json」\n2. 在电脑上用 sign_pass.sh 签名（需 Pass Type ID 证书）\n3. 通过 AirDrop 把 .pkpass 传回 iPhone\n4. 回到本页面「导入 .pkpass」加入 Wallet")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("添加卡片")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if let t = toast {
                    Text(t)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(toastError ? Color.red.opacity(0.9) : Color.black.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 20)
                }
            }
            .sheet(isPresented: $showingManualInput) {
                ManualInputView()
            }
            .sheet(isPresented: $showingPrefilledManual) {
                ManualInputView(
                    prefillUID: prefillUID,
                    prefillName: prefillName
                )
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { code in
                    handleScannedCode(code)
                }
            }
            .sheet(isPresented: $showingImportPass) {
                ImportPassView()
            }
            .fileImporter(
                isPresented: $showingJSONPicker,
                allowedContentTypes: [jsonType],
                allowsMultipleSelection: false
            ) { result in
                handleJSONImport(result)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            Text("选择添加方式")
                .font(.title3.bold())
            Text("支持手动输入、扫码识别、JSON 批量导入，或直接导入已签名的 .pkpass 加入 Apple Wallet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func entryCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    // MARK: - 扫码结果

    private func handleScannedCode(_ code: String) {
        // 尝试判断是纯 UID 还是 JSON 内容
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果是 JSON，直接导入
        if let data = trimmed.data(using: .utf8) {
            if let cards = try? CardImporter.parseCards(from: data), !cards.isEmpty {
                Task { @MainActor in
                    do {
                        for dto in cards {
                            try CardImporter.validate(dto)
                            _ = CardImporter.insert(dto, into: modelContext)
                        }
                        showToast("已从扫码导入 \(cards.count) 张卡")
                    } catch {
                        showToast("JSON 数据无效：\(error.localizedDescription)", error: true)
                    }
                }
                return
            }
        }

        // 否则作为 UID 预填入手动输入
        prefillUID = trimmed
        prefillName = "扫码卡 \(String(trimmed.prefix(8)))"
        showingPrefilledManual = true
    }

    // MARK: - JSON 导入

    private func handleJSONImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                showToast("未选择文件", error: true)
                return
            }
            Task { @MainActor in
                do {
                    let inserted = try CardImporter.importFromFile(url, into: modelContext)
                    showToast("成功导入 \(inserted.count) 张卡 ✓")
                } catch let err as CardImporter.ImportError {
                    showToast(err.errorDescription ?? "导入失败", error: true)
                } catch {
                    showToast("导入失败：\(error.localizedDescription)", error: true)
                }
            }
        case .failure(let err):
            showToast("选择文件失败：\(err.localizedDescription)", error: true)
        }
    }

    private func showToast(_ message: String, error: Bool = false) {
        toastError = error
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toast = nil }
        }
    }
}

#Preview {
    AddCardView()
        .modelContainer(for: NFCCard.self, inMemory: true)
}
