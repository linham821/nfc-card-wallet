import Foundation
import PassKit
import SwiftUI
import SwiftData

/// Pass 生成器：把 NFC 卡片信息打包为 .pkpass 文件并尝试加入 Apple Wallet。
///
/// 重要说明：
/// - iOS 上 PassKit 不允许 App 在设备端动态生成 .pkpass（必须由服务器用 Pass Type ID 证书签名）。
/// - 本类的 `addCardToWallet` 方法使用 PKAddPassesViewController 接收一个已签名的 .pkpass 数据。
/// - 若没有可用的签名 pass，会降级为「预览 Pass 设计」模式，仅展示卡面 UI（不真正加入系统钱包）。
/// - 想让真机可加到 Wallet：见 scripts/sign_pass.sh 与 README 中 Pass Type ID 证书申请流程。
@MainActor
final class PassGenerator: NSObject, ObservableObject {

    @Published var isLoading = false
    @Published var passController: PassControllerWrapper?
    @Published var lastError: String?
    @Published var previewPassData: PreviewPassData?

    struct PassControllerWrapper: Identifiable {
        let id = UUID()
        let controller: PKAddPassesViewController
    }

    struct PreviewPassData: Identifiable {
        let id = UUID()
        let name: String
        let uidDisplay: String
        let cardType: String
        let cardNumber: String
        let backgroundColorHex: String
        let foregroundColorHex: String
        let labelColorHex: String
        let logoText: String
    }

    /// 尝试把卡片加入 Wallet：
    /// 1. 先尝试从 App Bundle 加载预签名的 pass.template/pass.json（用于演示签名 pass 已存在的场景）
    /// 2. 若无可用 .pkpass，则进入预览模式
    func addCardToWallet(_ card: NFCCard) {
        isLoading = true
        lastError = nil
        previewPassData = nil

        Task {
            // 1) 尝试从 Bundle 读取预先签名的 pass.json 模板（由 sign_pass.sh 在构建期生成）
            if let passData = await self.loadBundledSignedPass(for: card),
               let pass = try? PKPass(data: passData),
               let controller = PKAddPassesViewController(pass: pass) {
                controller.delegate = self
                await MainActor.run {
                    self.passController = PassControllerWrapper(controller: controller)
                    self.isLoading = false
                }
                return
            }

            // 2) 降级到预览模式：构造一份 pass.json 内容，仅用于在 App 内展示 Pass 设计
            let preview = self.buildPreviewPassData(for: card)
            await MainActor.run {
                self.previewPassData = preview
                self.isLoading = false
            }
        }
    }

    // MARK: - 预览模式数据

    private func buildPreviewPassData(for card: NFCCard) -> PreviewPassData {
        let colors = PassGenerator.colorPalette[card.colorIndex % PassGenerator.colorPalette.count]
        return PreviewPassData(
            name: card.name,
            uidDisplay: card.uidDisplay,
            cardType: card.cardType,
            cardNumber: card.cardNumber,
            backgroundColorHex: colors.bg,
            foregroundColorHex: colors.fg,
            labelColorHex: colors.label,
            logoText: "NFC"
        )
    }

    // MARK: - 加载 Bundle 内的签名 pass

    private func loadBundledSignedPass(for card: NFCCard) async -> Data? {
        // 从 pass.template/ 读取 pass.json 模板，注入卡信息，然后...
        // 注意：这里只能"组装" pass 内容，不能签名；最终仍需服务端或 sign_pass.sh 在构建期签名。
        // 简化：演示路径——尝试读取 Bundle 里的 pass.json 并替换占位符，返回 nil 表示需要服务端签名
        guard let passJSONURL = Bundle.main.url(forResource: "pass", withExtension: "json") else {
            return nil
        }
        // 此处不做实际签名，返回 nil 触发预览模式
        _ = passJSONURL
        return nil
    }

    // MARK: - pass.json 模板（用于服务端或 sign_pass.sh 引用）

    static func passJSONTemplate(for card: NFCCard) -> [String: Any] {
        let colors = colorPalette[card.colorIndex % colorPalette.count]
        return [
            "description": "NFC Card Wallet 保存的卡片",
            "formatVersion": 1,
            "organizationName": "NFC Card Wallet",
            "passTypeIdentifier": "pass.com.nfccardwallet.app",
            "serialNumber": card.id.uuidString,
            "teamIdentifier": "TEAMIDXX",
            "generic": [
                "primaryFields": [
                    ["key": "name", "label": "卡片名称", "value": card.name]
                ],
                "secondaryFields": [
                    ["key": "uid", "label": "UID", "value": card.uidDisplay]
                ],
                "auxiliaryFields": [
                    ["key": "type", "label": "类型", "value": card.cardType],
                    ["key": "num", "label": "卡号", "value": card.cardNumber]
                ],
                "backFields": [
                    ["key": "info", "label": "说明", "value": "此 Pass 由 NFC Card Wallet App 生成，包含 NFC 卡 UID。仅用于扫码展示，不能作为 NFC 卡模拟使用。"]
                ]
            ],
            "backgroundColor": colors.bg,
            "foregroundColor": colors.fg,
            "labelColor": colors.label,
            "logoText": "NFC Card"
        ]
    }

    static let colorPalette: [(bg: String, fg: String, label: String)] = [
        ("rgb(44,62,80)",  "rgb(255,255,255)", "rgb(180,200,220)"),
        ("rgb(142,68,173)", "rgb(255,255,255)", "rgb(220,200,240)"),
        ("rgb(192,57,43)", "rgb(255,255,255)", "rgb(240,200,200)"),
        ("rgb(22,160,133)", "rgb(255,255,255)", "rgb(200,240,230)"),
        ("rgb(41,128,185)", "rgb(255,255,255)", "rgb(200,220,240)"),
        ("rgb(211,84,0)",  "rgb(255,255,255)", "rgb(255,220,200)")
    ]
}

extension PassGenerator: PKAddPassesViewControllerDelegate {
    nonisolated func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        Task { @MainActor in
            self.passController = nil
        }
    }
}
