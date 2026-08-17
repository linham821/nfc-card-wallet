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
        guard NFCReaderSession.readingAvailable else {
            errorMessage = "此设备不支持 NFC 读取"
            return
        }
        // 重置上一次结果
        lastResult = nil
        errorMessage = nil
        isScanning = true

        // 使用 TagReaderSession 可读取更详细的卡信息（UID/SAK/ATQA）
        let session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        )
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
            let sak = String(format: "0x%02X", mifare.sak)
            let atqa = String(format: "0x%04X", mifare.atqa)
            let typeStr = Self.mifareTypeName(sak: mifare.sak, identifier: mifare.identifier)
            let ndef = await readNDEF(from: .miFare(mifare))
            return ScanResult(uidHex: uid, cardType: typeStr, sakHex: sak, atqaHex: atqa, ndefInfo: ndef)

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

    nonisolated static func mifareTypeName(sak: UInt8, identifier: Data) -> String {
        // 根据常见 SAK 推断 MIFARE 卡子类型
        switch sak {
        case 0x00:
            // UID 长度 7 通常为 Ultralight/NTAG
            return identifier.count == 7 ? "MIFARE Ultralight / NTAG" : "MIFARE Classic (SAK 0x00)"
        case 0x08:
            return "MIFARE Classic 1K"
        case 0x18:
            return "MIFARE Classic 4K"
        case 0x09:
            return "MIFARE Mini"
        case 0x20, 0x28:
            return "MIFARE Plus / DESFire (ISO14443-4)"
        case 0x40:
            return "MIFARE Plus (SL0)"
        default:
            return "MIFARE (SAK 0x\(String(format: "%02X", sak)))"
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
