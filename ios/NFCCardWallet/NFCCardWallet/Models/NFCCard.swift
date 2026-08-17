import Foundation
import SwiftData

@Model
final class NFCCard {
    @Attribute(.unique) var id: UUID
    var name: String
    var uidHex: String
    var cardType: String
    var sakHex: String
    var atqaHex: String
    var ndefInfo: String
    var scannedAt: Date
    var addedToWallet: Bool
    var colorIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        uidHex: String,
        cardType: String,
        sakHex: String,
        atqaHex: String,
        ndefInfo: String,
        scannedAt: Date = .now,
        addedToWallet: Bool = false,
        colorIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.uidHex = uidHex
        self.cardType = cardType
        self.sakHex = sakHex
        self.atqaHex = atqaHex
        self.ndefInfo = ndefInfo
        self.scannedAt = scannedAt
        self.addedToWallet = addedToWallet
        self.colorIndex = colorIndex
    }
}

extension NFCCard {
    var uidDisplay: String {
        uidHex
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
            .chunked(into: 2)
            .joined(separator: ":")
    }

    var cardNumber: String {
        uidHex.replacingOccurrences(of: " ", with: "").uppercased()
    }

    var scannedAtDisplay: String {
        scannedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in self {
            current.append(ch)
            if current.count == size {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
