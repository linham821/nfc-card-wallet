import SwiftUI
import UniformTypeIdentifiers
import PassKit

/// 导入外部 .pkpass 文件并加入 Apple Wallet
/// 用户可在电脑上用 sign_pass.sh 生成签名后的 .pkpass，通过 AirDrop / 文件分享传到 iPhone
struct ImportPassView: View {

    @State private var showingPicker = false
    @State private var passController: PKAddPassesViewController?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var importedPassSummary: String?

    private let passType = UTType(filenameExtension: "pkpass") ?? UTType.data

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.green.opacity(0.6))

                    VStack(spacing: 8) {
                        Text("导入已签名的 .pkpass")
                            .font(.title3.bold())
                        Text("从电脑用 sign_pass.sh 生成签名后的 .pkpass 文件，通过 AirDrop 或文件 App 传到 iPhone，然后在此处选择文件加入 Apple Wallet。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 12) {
                        Button {
                            showingPicker = true
                        } label: {
                            Label("选择 .pkpass 文件", systemImage: "doc.badge.plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)

                        if let summary = importedPassSummary {
                            VStack(spacing: 8) {
                                Text("已加载 Pass")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(summary)
                                    .font(.callout)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        if let err = errorMessage {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                        }

                        if let succ = successMessage {
                            Label(succ, systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 20)

                    // 说明卡片
                    GroupBox("如何生成 .pkpass") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("前提：")
                                .font(.subheadline.weight(.semibold))
                            Text("• Apple Developer Program 付费会员（$99/年）\n• 在 Apple Developer Portal 申请 Pass Type ID\n• 下载 Pass Signing Certificate（.p12）")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Divider().padding(.vertical, 4)

                            Text("步骤：")
                                .font(.subheadline.weight(.semibold))
                            Text("1. 在 App 内为卡片生成 pass.json（见卡片详情页\"导出 pass.json\"按钮）\n2. 在电脑上用 sign_pass.sh 签名\n   ./scripts/sign_pass.sh <pass.json> <pass.p12> <passTypeID>\n3. 把生成的 .pkpass 通过 AirDrop 传到 iPhone\n4. 在此页面选择文件，加入 Wallet")
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
            .navigationTitle("导入 Pass")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showingPicker,
                allowedContentTypes: [passType],
                allowsMultipleSelection: false
            ) { result in
                handleFileResult(result)
            }
        }
    }

    private func handleFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "未选择文件"
                return
            }
            loadPass(from: url)
        case .failure(let err):
            errorMessage = "选择文件失败：\(err.localizedDescription)"
        }
    }

    private func loadPass(from url: URL) {
        errorMessage = nil
        successMessage = nil
        importedPassSummary = nil

        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            guard let pass = try? PKPass(data: data) else {
                errorMessage = "无法解析 .pkpass 文件，可能未正确签名或已损坏"
                return
            }

            // 显示 pass 摘要
            let summary = buildSummary(pass)
            importedPassSummary = summary

            // 弹出加入 Wallet 的系统界面
            if let controller = PKAddPassesViewController(pass: pass) {
                controller.delegate = PassControllerDelegateHandler.shared
                passController = controller
                UIApplication.shared.rootViewController?.present(controller, animated: true)
            } else {
                errorMessage = "无法启动加入 Wallet 流程（设备不支持 PassKit 或文件无效）"
            }
        } catch {
            errorMessage = "读取文件失败：\(error.localizedDescription)"
        }
    }

    private func buildSummary(_ pass: PKPass) -> String {
        var parts: [String] = []
        if !pass.localizedName.isEmpty { parts.append("名称: \(pass.localizedName)") }
        if !pass.organizationName.isEmpty { parts.append("发行方: \(pass.organizationName)") }
        if !pass.passTypeIdentifier.isEmpty { parts.append("类型: \(pass.passTypeIdentifier)") }
        return parts.isEmpty ? "（无 Pass 元数据）" : parts.joined(separator: "\n")
    }
}

/// PKAddPassesViewControllerDelegate 单例处理
final class PassControllerDelegateHandler: NSObject, PKAddPassesViewControllerDelegate {
    static let shared = PassControllerDelegateHandler()

    nonisolated func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        DispatchQueue.main.async {
            controller.dismiss(animated: true)
        }
    }
}

extension UIApplication {
    var rootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}
