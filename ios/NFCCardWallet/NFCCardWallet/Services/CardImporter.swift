import Foundation
import SwiftData
import SwiftUI

/// 卡片导入服务：处理 JSON 文件、JSON 字符串的解析与导入。
/// 支持单个对象和数组格式。
struct CardImporter {

    /// 导入错误
    enum ImportError: LocalizedError {
        case invalidJSON(String)
        case missingRequiredField(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let detail):
                return "JSON 解析失败：\(detail)"
            case .missingRequiredField(let field):
                return "缺少必填字段：\(field)"
            }
        }
    }

    /// JSON 卡片结构
    struct CardDTO: Codable {
        var name: String
        var uidHex: String
        var cardType: String
        var sakHex: String?
        var atqaHex: String?
        var ndefInfo: String?
        var colorIndex: Int?
    }

    /// 从 Data 解析卡片数组
    /// 支持格式：
    ///   - 单对象: {"name": "...", "uidHex": "..."}
    ///   - 数组: [{"name": "...", ...}, {...}]
    static func parseCards(from data: Data) throws -> [CardDTO] {
        let decoder = JSONDecoder()
        // 先尝试数组
        if let arr = try? decoder.decode([CardDTO].self, from: data) {
            return arr
        }
        // 再尝试单对象
        if let single = try? decoder.decode(CardDTO.self, from: data) {
            return [single]
        }
        // 都失败，给出详细错误
        do {
            _ = try decoder.decode([CardDTO].self, from: data)
        } catch {
            do {
                _ = try decoder.decode(CardDTO.self, from: data)
            } catch let singleErr {
                throw ImportError.invalidJSON(singleErr.localizedDescription)
            }
        }
        return []
    }

    /// 验证 DTO 完整性
    static func validate(_ dto: CardDTO) throws {
        if dto.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ImportError.missingRequiredField("name")
        }
        if dto.uidHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ImportError.missingRequiredField("uidHex")
        }
    }

    /// 把 DTO 插入 SwiftData
    @MainActor
    static func insert(_ dto: CardDTO, into context: ModelContext, colorIndex: Int? = nil) -> NFCCard {
        let card = NFCCard(
            name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines),
            uidHex: dto.uidHex.trimmingCharacters(in: .whitespacesAndNewlines),
            cardType: dto.cardType.trimmingCharacters(in: .whitespacesAndNewlines),
            sakHex: dto.sakHex ?? "—",
            atqaHex: dto.atqaHex ?? "—",
            ndefInfo: dto.ndefInfo ?? "—",
            colorIndex: dto.colorIndex ?? colorIndex ?? 0
        )
        context.insert(card)
        try? context.save()
        return card
    }

    /// 从 URL（文件）导入
    @MainActor
    static func importFromFile(_ url: URL, into context: ModelContext) throws -> [NFCCard] {
        // 启动安全作用域访问
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let dtos = try parseCards(from: data)
        var inserted: [NFCCard] = []
        let baseColor = (try? context.fetchCount(FetchDescriptor<NFCCard>())) ?? 0
        for (i, dto) in dtos.enumerated() {
            try validate(dto)
            let card = insert(dto, into: context, colorIndex: baseColor + i)
            inserted.append(card)
        }
        return inserted
    }

    /// 导出卡片为 JSON Data
    static func exportCards(_ cards: [NFCCard]) throws -> Data {
        let dtos = cards.map { card in
            CardDTO(
                name: card.name,
                uidHex: card.uidHex,
                cardType: card.cardType,
                sakHex: card.sakHex == "—" ? nil : card.sakHex,
                atqaHex: card.atqaHex == "—" ? nil : card.atqaHex,
                ndefInfo: card.ndefInfo == "—" ? nil : card.ndefInfo,
                colorIndex: card.colorIndex
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dtos)
    }

    /// 示例 JSON 模板（供用户参考格式）
    static let sampleTemplate: String = """
    [
      {
        "name": "门禁卡",
        "uidHex": "04 A3 12 5F 7B 81",
        "cardType": "MIFARE Ultralight",
        "sakHex": "0x00",
        "atqaHex": "0x4400",
        "ndefInfo": "无",
        "colorIndex": 0
      },
      {
        "name": "公交卡",
        "uidHex": "D3 91 8A 22",
        "cardType": "MIFARE DESFire",
        "colorIndex": 3
      }
    ]
    """
}
