import Foundation
import CoreNFC
import SwiftUI

@MainActor
final class NFCReader: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastResult: ScanResult?
    @Published var errorMessage: String?

    private var session: NFCReaderSession?

    override init() {
        super.init()
    }

    func startScanning() {
        // NFCReaderSession.readingAvailable 检查硬件能力 + App 是否有 NFC Reader Session entitlement
        guard NFCReaderSession.readingAvailable else {
            errorMessage = """
NFC 不可用

根本原因：Free Apple ID 无法获取 NFC 权限
─────────────────────────────
iOS 通过 embedded.mobileprovision 检查权限。Sideloadly 用免费 Apple ID 重签时，Apple 服务器会丢弃 com.apple.developer.nfc.readersession entitlement（免费账号无此 capability）。即使 IPA 中注入了 entitlement，运行时也会被忽略。

解决方案（任选其一）：
1. 付费 Apple Developer Program（$99/年）
   - 注册后到 App IDs 启用 NFC Tag Reading capability
   - 用付费账号重新签名 IPA
2. 使用别人的付费开发者账号证书
   - 导出 .p12 + provisioning profile
   - Sideloadly 选 "Custom Certificate" 模式签名
3. 越狱 iPhone（需对应 iOS 版本的越狱工具）
   - 越狱后绕过 entitlement 检查
4. TrollStore 永久签名（仅特定 iOS 版本支持）
"""
            return
        }
        // 重置上一次结果
        lastResult = nil
        errorMessage = nil
        isScanning = true

        // 使用 TagReaderSession 可读取更详细的卡信息（UID/SAK/ATQA）
        guard let session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        ) else {
            errorMessage = "无法启动 NFC 会话"
            isScanning = false
            return
        }
        session.alertMessage = "请将 NFC 卡片靠近 iPhone 背部"
        session.begin()
        self.session = session
    }

    func stopScanning() {
        session?.invalidate()
        session = nil
        isScanning = false
    }

    struct ScanResult {
        let uidHex: String
        let cardType: String
        let sakHex: String
        let atqaHex: String
        let ndefInfo: String
    }
}

extension NFCReader: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session 已激活，等待检测标签
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nsError = error as NSError
        let message: String
        if nsError.code == NFCReaderError.readerSessionInvalidationErrorFirstNDEFTagRead.rawValue
            || nsError.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
            message = "" // 用户取消或正常结束
        } else {
            message = "读取失败：\(error.localizedDescription)"
        }
        Task { @MainActor in
            self.isScanning = false
            if !message.isEmpty { self.errorMessage = message }
            self.session = nil
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "未检测到标签")
            return
        }
        Task { @MainActor in
            await self.process(tag: tag, in: session)
        }
    }

    private func process(tag: NFCTag, in session: NFCTagReaderSession) async {
        do {
            try await connect(tag: tag, in: session)
            let result = try await readInfo(from: tag)
            self.lastResult = result
            session.alertMessage = "读取成功"
            session.invalidate()
            self.isScanning = false
            self.session = nil
        } catch {
            session.invalidate(errorMessage: "读取卡片失败：\(error.localizedDescription)")
            self.isScanning = false
            self.session = nil
        }
    }

    private func connect(tag: NFCTag, in session: NFCTagReaderSession) async throws {
        switch tag {
        case .miFare(let mifare):
            try await session.connect(to: .miFare(mifare))
        case .feliCa(let felica):
            try await session.connect(to: .feliCa(felica))
        case .iso15693(let iso15693):
            try await session.connect(to: .iso15693(iso15693))
        case .iso7816(let iso7816):
            try await session.connect(to: .iso7816(iso7816))
        @unknown default:
            throw NFCError.unsupportedTag
        }
    }

    @MainActor
    private func readInfo(from tag: NFCTag) async throws -> ScanResult {
        switch tag {
        case .miFare(let mifare):
            let uid = mifare.identifier.map { String(format: "%02X", $0) }.joined(separator: " ")
            // NFCMiFareTag 不直接暴露 SAK/ATQA，使用 mifareFamily 推断类型
            let typeStr = Self.mifareFamilyName(mifare.mifareFamily)
            let ndef = await readNDEF(from: .miFare(mifare))
            return ScanResult(uidHex: uid, cardType: typeStr, sakHex: "—", atqaHex: "—", ndefInfo: ndef)

        case .feliCa(let felica):
            let uid = felica.currentIDm.map { String(format: "%02X", $0) }.joined(separator: " ")
            return ScanResult(uidHex: uid, cardType: "FeliCa", sakHex: "—", atqaHex: "—", ndefInfo: "—")

        case .iso15693(let iso15693):
            let uid = iso15693.identifier.map { String(format: "%02X", $0) }.joined(separator: " ")
            return ScanResult(uidHex: uid, cardType: "ISO15693", sakHex: "—", atqaHex: "—", ndefInfo: "—")

        case .iso7816(let iso7816):
            let uid = iso7816.identifier.map { String(format: "%02X", $0) }.joined(separator: " ")
            return ScanResult(uidHex: uid, cardType: "ISO7816 / ISO14443-4", sakHex: "—", atqaHex: "—", ndefInfo: "—")

        @unknown default:
            throw NFCError.unsupportedTag
        }
    }

    private func readNDEF(from tag: NFCTag) async -> String {
        // 简化：尝试读取 NDEF 信息，失败则返回"无"
        // 这里不展开完整的 NDEF 读取流程，避免占用过多篇幅
        return "未检测"
    }

    nonisolated static func mifareFamilyName(_ family: NFCMiFareFamily) -> String {
        switch family {
        case .unknown:
            return "MIFARE (Unknown)"
        case .ultralight:
            return "MIFARE Ultralight"
        case .plus:
            return "MIFARE Plus"
        case .desfire:
            return "MIFARE DESFire"
        @unknown default:
            return "MIFARE"
        }
    }
}

enum NFCError: LocalizedError {
    case unsupportedTag

    var errorDescription: String? {
        switch self {
        case .unsupportedTag:
            return "不支持的标签类型"
        }
    }
}
